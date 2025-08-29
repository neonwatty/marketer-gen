'use client'

import { useEffect, useState } from 'react'
import { useForm } from 'react-hook-form'

import { zodResolver } from '@hookform/resolvers/zod'
import { Clock,Plus, Trash2, X } from 'lucide-react'
import * as z from 'zod'

import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import {
  Form,
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from '@/components/ui/form'
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
import type { Node } from 'reactflow'

// Enhanced stage interface with timing configuration
export interface EnhancedJourneyStage extends JourneyStage {
  timing?: {
    duration: number
    durationUnit: 'days' | 'weeks' | 'months'
    delay: number
    delayUnit: 'hours' | 'days' | 'weeks'
  }
  channels?: string[]
}

// Form validation schema
const stageConfigSchema = z.object({
  type: z.enum(['awareness', 'consideration', 'conversion', 'retention']),
  title: z.string().min(1, 'Title is required').max(50, 'Title must be less than 50 characters'),
  description: z.string().min(1, 'Description is required').max(200, 'Description must be less than 200 characters'),
  contentTypes: z.array(z.string()).min(1, 'At least one content type is required'),
  messagingSuggestions: z.array(z.string()).min(1, 'At least one messaging suggestion is required'),
  timing: z.object({
    duration: z.number().min(1, 'Duration must be at least 1').max(365, 'Duration cannot exceed 365'),
    durationUnit: z.enum(['days', 'weeks', 'months']),
    delay: z.number().min(0, 'Delay cannot be negative').max(30, 'Delay cannot exceed 30'),
    delayUnit: z.enum(['hours', 'days', 'weeks']),
  }).optional(),
  channels: z.array(z.string()).optional(),
})

type StageFormData = z.infer<typeof stageConfigSchema>

interface StageConfigurationPanelProps {
  isOpen: boolean
  onClose: () => void
  stage: Node | null
  onUpdate: (nodeId: string, updatedData: Partial<EnhancedJourneyStage>) => void
  onDelete: (nodeId: string) => void
}

const stageTypeOptions = [
  { value: 'awareness', label: 'Awareness' },
  { value: 'consideration', label: 'Consideration' },
  { value: 'conversion', label: 'Conversion' },
  { value: 'retention', label: 'Retention' },
]

const channelSuggestions = [
  'Email',
  'Social Media',
  'Website',
  'Mobile App',
  'SMS',
  'Direct Mail',
  'Paid Ads',
  'Content Marketing',
  'SEO',
  'Webinars',
  'Events',
  'Partnerships',
  'Influencer Marketing',
  'PR',
  'Community',
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
  const [newContentType, setNewContentType] = useState('')
  const [newMessage, setNewMessage] = useState('')
  const [newChannel, setNewChannel] = useState('')

  const form = useForm<StageFormData>({
    resolver: zodResolver(stageConfigSchema),
    defaultValues: {
      type: 'awareness',
      title: '',
      description: '',
      contentTypes: [],
      messagingSuggestions: [],
      timing: {
        duration: 7,
        durationUnit: 'days',
        delay: 0,
        delayUnit: 'hours',
      },
      channels: [],
    },
  })

  // Reset form when stage changes
  useEffect(() => {
    if (stage?.data) {
      const stageData = stage.data as EnhancedJourneyStage
      form.reset({
        type: stageData.type,
        title: stageData.title,
        description: stageData.description,
        contentTypes: stageData.contentTypes || [],
        messagingSuggestions: stageData.messagingSuggestions || [],
        timing: stageData.timing || {
          duration: 7,
          durationUnit: 'days',
          delay: 0,
          delayUnit: 'hours',
        },
        channels: stageData.channels || [],
      })
    }
  }, [stage, form])

  const handleSave = (data: StageFormData) => {
    if (stage) {
      onUpdate(stage.id, data)
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
    const currentTypes = form.getValues('contentTypes')
    if (contentType && !currentTypes.includes(contentType)) {
      form.setValue('contentTypes', [...currentTypes, contentType], {
        shouldValidate: true,
      })
    }
  }

  const removeContentType = (contentType: string) => {
    const currentTypes = form.getValues('contentTypes')
    form.setValue('contentTypes', currentTypes.filter(ct => ct !== contentType), {
      shouldValidate: true,
    })
  }

  const addMessage = (message: string) => {
    const currentMessages = form.getValues('messagingSuggestions')
    if (message && !currentMessages.includes(message)) {
      form.setValue('messagingSuggestions', [...currentMessages, message], {
        shouldValidate: true,
      })
    }
  }

  const removeMessage = (message: string) => {
    const currentMessages = form.getValues('messagingSuggestions')
    form.setValue('messagingSuggestions', currentMessages.filter(msg => msg !== message), {
      shouldValidate: true,
    })
  }

  const addChannel = (channel: string) => {
    const currentChannels = form.getValues('channels') || []
    if (channel && !currentChannels.includes(channel)) {
      form.setValue('channels', [...currentChannels, channel], {
        shouldValidate: true,
      })
    }
  }

  const removeChannel = (channel: string) => {
    const currentChannels = form.getValues('channels') || []
    form.setValue('channels', currentChannels.filter(ch => ch !== channel), {
      shouldValidate: true,
    })
  }

  if (!stage) return null

  const watchedType = form.watch('type')
  const watchedContentTypes = form.watch('contentTypes')
  const watchedMessages = form.watch('messagingSuggestions')
  const watchedChannels = form.watch('channels') || []

  const availableContentTypes = contentTypeSuggestions[watchedType] || []
  const availableMessages = messagingSuggestions[watchedType] || []

  return (
    <Sheet open={isOpen} onOpenChange={onClose}>
      <SheetContent className="w-[400px] sm:w-[540px] overflow-y-auto">
        <SheetHeader>
          <SheetTitle>Configure Journey Stage</SheetTitle>
          <SheetDescription>
            Customize the stage details, content types, messaging, and timing.
          </SheetDescription>
        </SheetHeader>

        <Form {...form}>
          <form onSubmit={form.handleSubmit(handleSave)} className="space-y-6 py-4">
            {/* Stage Type */}
            <FormField
              control={form.control}
              name="type"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Stage Type</FormLabel>
                  <Select onValueChange={field.onChange} value={field.value}>
                    <FormControl>
                      <SelectTrigger>
                        <SelectValue placeholder="Select stage type" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      {stageTypeOptions.map((option) => (
                        <SelectItem key={option.value} value={option.value}>
                          {option.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />

            {/* Title */}
            <FormField
              control={form.control}
              name="title"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Title</FormLabel>
                  <FormControl>
                    <Input placeholder="Enter stage title" {...field} />
                  </FormControl>
                  <FormDescription>
                    A clear, descriptive name for this journey stage
                  </FormDescription>
                  <FormMessage />
                </FormItem>
              )}
            />

            {/* Description */}
            <FormField
              control={form.control}
              name="description"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Description</FormLabel>
                  <FormControl>
                    <Textarea 
                      placeholder="Describe the purpose and goals of this stage"
                      rows={3}
                      {...field}
                    />
                  </FormControl>
                  <FormDescription>
                    Explain what this stage aims to achieve in the customer journey
                  </FormDescription>
                  <FormMessage />
                </FormItem>
              )}
            />

            {/* Timing Configuration */}
            <div className="space-y-4">
              <div className="flex items-center gap-2">
                <Clock className="h-4 w-4" />
                <Label className="text-sm font-medium">Timing Configuration</Label>
              </div>
              
              <div className="grid grid-cols-2 gap-4">
                <FormField
                  control={form.control}
                  name="timing.duration"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Duration</FormLabel>
                      <FormControl>
                        <Input 
                          type="number" 
                          min="1"
                          max="365"
                          {...field}
                          onChange={(e) => field.onChange(Number(e.target.value))}
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                
                <FormField
                  control={form.control}
                  name="timing.durationUnit"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Unit</FormLabel>
                      <Select onValueChange={field.onChange} value={field.value}>
                        <FormControl>
                          <SelectTrigger>
                            <SelectValue />
                          </SelectTrigger>
                        </FormControl>
                        <SelectContent>
                          <SelectItem value="days">Days</SelectItem>
                          <SelectItem value="weeks">Weeks</SelectItem>
                          <SelectItem value="months">Months</SelectItem>
                        </SelectContent>
                      </Select>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <FormField
                  control={form.control}
                  name="timing.delay"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Delay</FormLabel>
                      <FormControl>
                        <Input 
                          type="number" 
                          min="0"
                          max="30"
                          {...field}
                          onChange={(e) => field.onChange(Number(e.target.value))}
                        />
                      </FormControl>
                      <FormDescription>
                        Delay before this stage begins
                      </FormDescription>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                
                <FormField
                  control={form.control}
                  name="timing.delayUnit"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Delay Unit</FormLabel>
                      <Select onValueChange={field.onChange} value={field.value}>
                        <FormControl>
                          <SelectTrigger>
                            <SelectValue />
                          </SelectTrigger>
                        </FormControl>
                        <SelectContent>
                          <SelectItem value="hours">Hours</SelectItem>
                          <SelectItem value="days">Days</SelectItem>
                          <SelectItem value="weeks">Weeks</SelectItem>
                        </SelectContent>
                      </Select>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>
            </div>

            {/* Content Types */}
            <div className="space-y-4">
              <Label className="text-sm font-medium">Content Types</Label>
              <div className="flex flex-wrap gap-1 mb-2">
                {watchedContentTypes.map((contentType) => (
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
                      e.preventDefault()
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
                Suggestions for {watchedType}:
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
              {form.formState.errors.contentTypes && (
                <p className="text-sm text-destructive">
                  {form.formState.errors.contentTypes.message}
                </p>
              )}
            </div>

            {/* Channels */}
            <div className="space-y-4">
              <Label className="text-sm font-medium">Marketing Channels</Label>
              <div className="flex flex-wrap gap-1 mb-2">
                {watchedChannels.map((channel) => (
                  <Badge key={channel} variant="secondary" className="gap-1">
                    {channel}
                    <X
                      className="h-3 w-3 cursor-pointer"
                      onClick={() => removeChannel(channel)}
                    />
                  </Badge>
                ))}
              </div>
              <div className="flex gap-2">
                <Input
                  placeholder="Add custom channel"
                  value={newChannel}
                  onChange={(e) => setNewChannel(e.target.value)}
                  onKeyPress={(e) => {
                    if (e.key === 'Enter') {
                      e.preventDefault()
                      addChannel(newChannel)
                      setNewChannel('')
                    }
                  }}
                />
                <Button
                  type="button"
                  size="sm"
                  onClick={() => {
                    addChannel(newChannel)
                    setNewChannel('')
                  }}
                >
                  <Plus className="h-4 w-4" />
                </Button>
              </div>
              <div className="text-sm text-muted-foreground">
                Available channels:
              </div>
              <div className="flex flex-wrap gap-1">
                {channelSuggestions.map((suggestion) => (
                  <Badge
                    key={suggestion}
                    variant="outline"
                    className="cursor-pointer hover:bg-secondary"
                    onClick={() => addChannel(suggestion)}
                  >
                    {suggestion}
                  </Badge>
                ))}
              </div>
            </div>

            {/* Messaging Suggestions */}
            <div className="space-y-4">
              <Label className="text-sm font-medium">Messaging Suggestions</Label>
              <div className="space-y-1">
                {watchedMessages.map((message, index) => (
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
                      e.preventDefault()
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
                Suggestions for {watchedType}:
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
              {form.formState.errors.messagingSuggestions && (
                <p className="text-sm text-destructive">
                  {form.formState.errors.messagingSuggestions.message}
                </p>
              )}
            </div>

            <SheetFooter className="flex justify-between mt-6 pt-6 border-t">
              <Button type="button" variant="destructive" onClick={handleDelete}>
                <Trash2 className="h-4 w-4 mr-2" />
                Delete Stage
              </Button>
              <div className="flex gap-2">
                <Button type="button" variant="outline" onClick={onClose}>
                  Cancel
                </Button>
                <Button type="submit">Save Changes</Button>
              </div>
            </SheetFooter>
          </form>
        </Form>
      </SheetContent>
    </Sheet>
  )
}