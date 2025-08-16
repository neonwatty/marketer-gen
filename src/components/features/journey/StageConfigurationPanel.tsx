'use client'

import { useEffect, useState } from 'react'

import { Plus, Trash2, X } from 'lucide-react'
import type { Node } from 'reactflow'

import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet'
import { Textarea } from '@/components/ui/textarea'

import type { JourneyStage } from './JourneyBuilder'

interface StageConfigurationPanelProps {
  isOpen: boolean
  onClose: () => void
  stage: Node | null
  onUpdate: (nodeId: string, updatedData: Partial<JourneyStage>) => void
  onDelete: (nodeId: string) => void
}

const stageTypeOptions = [
  { value: 'awareness', label: 'Awareness' },
  { value: 'consideration', label: 'Consideration' },
  { value: 'conversion', label: 'Conversion' },
  { value: 'retention', label: 'Retention' },
]

const contentTypeSuggestions = {
  awareness: [
    'Blog Posts',
    'Social Media Posts',
    'Video Content',
    'Infographics',
    'Podcasts',
    'SEO Content',
    'Display Ads',
    'PR Articles',
  ],
  consideration: [
    'Whitepapers',
    'eBooks',
    'Webinars',
    'Case Studies',
    'Product Comparisons',
    'Demo Videos',
    'FAQ Content',
    'Reviews & Testimonials',
  ],
  conversion: [
    'Product Demos',
    'Free Trials',
    'Pricing Pages',
    'Landing Pages',
    'Sales Presentations',
    'Consultation Offers',
    'Limited-time Offers',
    'Product Configurators',
  ],
  retention: [
    'Email Newsletters',
    'Support Documentation',
    'Community Forums',
    'User Onboarding',
    'Feature Updates',
    'Success Stories',
    'Loyalty Programs',
    'Feedback Surveys',
  ],
}

const messagingSuggestions = {
  awareness: [
    'Introduce your brand values',
    'Share educational content',
    'Tell your brand story',
    'Address industry challenges',
    'Build thought leadership',
    'Create emotional connections',
  ],
  consideration: [
    'Demonstrate expertise',
    'Show social proof',
    'Address pain points',
    'Compare solutions',
    'Provide detailed information',
    'Build trust and credibility',
  ],
  conversion: [
    'Create urgency',
    'Highlight unique value',
    'Reduce friction',
    'Offer guarantees',
    'Provide clear next steps',
    'Address objections',
  ],
  retention: [
    'Provide ongoing value',
    'Build community',
    'Gather feedback',
    'Celebrate milestones',
    'Encourage advocacy',
    'Prevent churn',
  ],
}

export function StageConfigurationPanel({
  isOpen,
  onClose,
  stage,
  onUpdate,
  onDelete,
}: StageConfigurationPanelProps) {
  const [formData, setFormData] = useState<Partial<JourneyStage>>({})
  const [newContentType, setNewContentType] = useState('')
  const [newMessage, setNewMessage] = useState('')

  useEffect(() => {
    if (stage?.data) {
      setFormData(stage.data)
    }
  }, [stage])

  const handleSave = () => {
    if (stage && formData) {
      onUpdate(stage.id, formData)
      onClose()
    }
  }

  const handleDelete = () => {
    if (stage) {
      onDelete(stage.id)
      onClose()
    }
  }

  const addContentType = (contentType: string) => {
    if (contentType && !formData.contentTypes?.includes(contentType)) {
      setFormData((prev) => ({
        ...prev,
        contentTypes: [...(prev.contentTypes || []), contentType],
      }))
    }
  }

  const removeContentType = (contentType: string) => {
    setFormData((prev) => ({
      ...prev,
      contentTypes: prev.contentTypes?.filter((ct) => ct !== contentType) || [],
    }))
  }

  const addMessage = (message: string) => {
    if (message && !formData.messagingSuggestions?.includes(message)) {
      setFormData((prev) => ({
        ...prev,
        messagingSuggestions: [...(prev.messagingSuggestions || []), message],
      }))
    }
  }

  const removeMessage = (message: string) => {
    setFormData((prev) => ({
      ...prev,
      messagingSuggestions:
        prev.messagingSuggestions?.filter((msg) => msg !== message) || [],
    }))
  }

  if (!stage) return null

  const stageType = formData.type || 'awareness'
  const availableContentTypes = contentTypeSuggestions[stageType] || []
  const availableMessages = messagingSuggestions[stageType] || []

  return (
    <Sheet open={isOpen} onOpenChange={onClose}>
      <SheetContent className="w-[400px] sm:w-[540px]">
        <SheetHeader>
          <SheetTitle>Configure Journey Stage</SheetTitle>
          <SheetDescription>
            Customize the stage details, content types, and messaging.
          </SheetDescription>
        </SheetHeader>

        <div className="grid gap-4 py-4">
          {/* Stage Type */}
          <div className="grid grid-cols-4 items-center gap-4">
            <Label htmlFor="type" className="text-right">
              Type
            </Label>
            <Select
              value={formData.type}
              onValueChange={(value: JourneyStage['type']) =>
                setFormData((prev) => ({ ...prev, type: value }))
              }
            >
              <SelectTrigger className="col-span-3">
                <SelectValue placeholder="Select stage type" />
              </SelectTrigger>
              <SelectContent>
                {stageTypeOptions.map((option) => (
                  <SelectItem key={option.value} value={option.value}>
                    {option.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {/* Title */}
          <div className="grid grid-cols-4 items-center gap-4">
            <Label htmlFor="title" className="text-right">
              Title
            </Label>
            <Input
              id="title"
              value={formData.title || ''}
              onChange={(e) =>
                setFormData((prev) => ({ ...prev, title: e.target.value }))
              }
              className="col-span-3"
            />
          </div>

          {/* Description */}
          <div className="grid grid-cols-4 items-start gap-4">
            <Label htmlFor="description" className="text-right pt-2">
              Description
            </Label>
            <Textarea
              id="description"
              value={formData.description || ''}
              onChange={(e) =>
                setFormData((prev) => ({ ...prev, description: e.target.value }))
              }
              className="col-span-3"
              rows={3}
            />
          </div>

          {/* Content Types */}
          <div className="space-y-2">
            <Label>Content Types</Label>
            <div className="flex flex-wrap gap-1 mb-2">
              {formData.contentTypes?.map((contentType) => (
                <Badge key={contentType} variant="secondary" className="gap-1">
                  {contentType}
                  <X
                    className="h-3 w-3 cursor-pointer"
                    onClick={() => removeContentType(contentType)}
                  />
                </Badge>
              ))}
            </div>
            <div className="flex gap-2">
              <Input
                placeholder="Add custom content type"
                value={newContentType}
                onChange={(e) => setNewContentType(e.target.value)}
                onKeyPress={(e) => {
                  if (e.key === 'Enter') {
                    addContentType(newContentType)
                    setNewContentType('')
                  }
                }}
              />
              <Button
                type="button"
                size="sm"
                onClick={() => {
                  addContentType(newContentType)
                  setNewContentType('')
                }}
              >
                <Plus className="h-4 w-4" />
              </Button>
            </div>
            <div className="text-sm text-muted-foreground">
              Suggestions for {stageType}:
            </div>
            <div className="flex flex-wrap gap-1">
              {availableContentTypes.map((suggestion) => (
                <Badge
                  key={suggestion}
                  variant="outline"
                  className="cursor-pointer hover:bg-secondary"
                  onClick={() => addContentType(suggestion)}
                >
                  {suggestion}
                </Badge>
              ))}
            </div>
          </div>

          {/* Messaging Suggestions */}
          <div className="space-y-2">
            <Label>Messaging Suggestions</Label>
            <div className="space-y-1">
              {formData.messagingSuggestions?.map((message, index) => (
                <div key={index} className="flex items-center justify-between p-2 bg-secondary rounded">
                  <span className="text-sm">{message}</span>
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={() => removeMessage(message)}
                  >
                    <X className="h-3 w-3" />
                  </Button>
                </div>
              ))}
            </div>
            <div className="flex gap-2">
              <Input
                placeholder="Add custom message"
                value={newMessage}
                onChange={(e) => setNewMessage(e.target.value)}
                onKeyPress={(e) => {
                  if (e.key === 'Enter') {
                    addMessage(newMessage)
                    setNewMessage('')
                  }
                }}
              />
              <Button
                type="button"
                size="sm"
                onClick={() => {
                  addMessage(newMessage)
                  setNewMessage('')
                }}
              >
                <Plus className="h-4 w-4" />
              </Button>
            </div>
            <div className="text-sm text-muted-foreground">
              Suggestions for {stageType}:
            </div>
            <div className="space-y-1">
              {availableMessages.map((suggestion) => (
                <div
                  key={suggestion}
                  className="p-2 bg-muted rounded cursor-pointer hover:bg-secondary text-sm"
                  onClick={() => addMessage(suggestion)}
                >
                  {suggestion}
                </div>
              ))}
            </div>
          </div>
        </div>

        <SheetFooter className="flex justify-between">
          <Button variant="destructive" onClick={handleDelete}>
            <Trash2 className="h-4 w-4 mr-2" />
            Delete Stage
          </Button>
          <div className="flex gap-2">
            <Button variant="outline" onClick={onClose}>
              Cancel
            </Button>
            <Button onClick={handleSave}>Save Changes</Button>
          </div>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}