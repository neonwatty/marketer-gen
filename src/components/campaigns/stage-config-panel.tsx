"use client"

import * as React from "react"
import { zodResolver } from "@hookform/resolvers/zod"
import { useForm } from "react-hook-form"
import * as z from "zod"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Badge } from "@/components/ui/badge"
import { Checkbox } from "@/components/ui/checkbox"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage, FormDescription } from "@/components/ui/form"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Separator } from "@/components/ui/separator"
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle, SheetTrigger } from "@/components/ui/sheet"
import {
  Users,
  Mail,
  Share2,
  FileText,
  Target,
  Plus,
  X,
  Lightbulb,
  CheckCircle,
  AlertCircle,
  Info,
} from "lucide-react"
import { cn } from "@/lib/utils"
import type { JourneyStage } from "./journey-builder"

// Validation schema for stage configuration
const stageConfigSchema = z.object({
  name: z.string().min(1, "Stage name is required").max(100, "Stage name must be less than 100 characters"),
  description: z.string().min(1, "Description is required").max(500, "Description must be less than 500 characters"),
  type: z.enum(["awareness", "consideration", "conversion", "retention"]),
  channels: z.array(z.string()).min(1, "At least one channel is required"),
  contentTypes: z.array(z.string()).min(1, "At least one content type is required"),
  customChannels: z.array(z.string()).optional(),
  customContentTypes: z.array(z.string()).optional(),
  messagingGuidance: z.string().max(1000, "Messaging guidance must be less than 1000 characters").optional(),
  targetAudience: z.string().max(500, "Target audience must be less than 500 characters").optional(),
  kpis: z.array(z.string()).optional(),
})

type StageConfigFormData = z.infer<typeof stageConfigSchema>

// Stage-specific recommendations
const STAGE_RECOMMENDATIONS = {
  awareness: {
    channels: ["Social Media", "Blog", "Display Ads", "SEO", "Influencer Marketing", "Content Marketing", "PR"],
    contentTypes: ["Blog Posts", "Social Posts", "Infographics", "Videos", "Podcasts", "Press Releases", "Educational Content"],
    messagingTips: [
      "Focus on educating your audience about the problem",
      "Build brand awareness without being overly promotional",
      "Create valuable, shareable content",
      "Use broad targeting to reach new audiences"
    ],
    kpis: ["Impressions", "Reach", "Website Traffic", "Brand Awareness", "Social Media Followers", "Content Engagement"]
  },
  consideration: {
    channels: ["Email", "Landing Pages", "Webinars", "Whitepapers", "Search Ads", "Retargeting", "Content Hub"],
    contentTypes: ["Email Series", "Case Studies", "Product Demos", "Comparisons", "Whitepapers", "Webinars", "Free Tools"],
    messagingTips: [
      "Highlight your unique value proposition",
      "Address common objections and concerns",
      "Provide social proof and testimonials",
      "Focus on benefits over features"
    ],
    kpis: ["Lead Generation", "Email Opens", "Click-through Rate", "Demo Requests", "Time on Site", "Pages per Session"]
  },
  conversion: {
    channels: ["Email", "Landing Pages", "Retargeting", "Sales", "Live Chat", "Phone", "In-app"],
    contentTypes: ["Product Pages", "Testimonials", "Offers", "CTAs", "Pricing Pages", "FAQ", "Sales Collateral"],
    messagingTips: [
      "Create urgency with limited-time offers",
      "Remove friction from the purchase process",
      "Provide clear pricing and value",
      "Use strong, action-oriented language"
    ],
    kpis: ["Conversion Rate", "Sales", "Revenue", "Cart Abandonment", "Cost per Acquisition", "Average Order Value"]
  },
  retention: {
    channels: ["Email", "Support", "Community", "Upsell", "In-app", "SMS", "Account Management"],
    contentTypes: ["Onboarding", "Tutorials", "Updates", "Loyalty Programs", "User-generated Content", "Support Content"],
    messagingTips: [
      "Focus on customer success and value realization",
      "Provide ongoing support and education",
      "Celebrate milestones and achievements",
      "Identify expansion opportunities"
    ],
    kpis: ["Customer Lifetime Value", "Churn Rate", "Net Promoter Score", "Product Usage", "Support Tickets", "Upsell Revenue"]
  }
}

interface StageConfigPanelProps {
  stage: JourneyStage | null
  isOpen: boolean
  onClose: () => void
  onSave: (stageId: string, config: Partial<JourneyStage>) => void
}

export function StageConfigPanel({ stage, isOpen, onClose, onSave }: StageConfigPanelProps) {
  const [newChannel, setNewChannel] = React.useState("")
  const [newContentType, setNewContentType] = React.useState("")

  const form = useForm<StageConfigFormData>({
    resolver: zodResolver(stageConfigSchema),
    defaultValues: {
      name: stage?.name || "",
      description: stage?.description || "",
      type: stage?.type || "awareness",
      channels: stage?.channels || [],
      contentTypes: stage?.contentTypes || [],
      customChannels: [],
      customContentTypes: [],
      messagingGuidance: "",
      targetAudience: "",
      kpis: [],
    },
  })

  // Reset form when stage changes
  React.useEffect(() => {
    if (stage) {
      form.reset({
        name: stage.name,
        description: stage.description,
        type: stage.type,
        channels: stage.channels,
        contentTypes: stage.contentTypes,
        customChannels: [],
        customContentTypes: [],
        messagingGuidance: "",
        targetAudience: "",
        kpis: [],
      })
    }
  }, [stage, form])

  const currentType = form.watch("type")
  const currentChannels = form.watch("channels")
  const currentContentTypes = form.watch("contentTypes")
  const recommendations = STAGE_RECOMMENDATIONS[currentType]

  const onSubmit = (data: StageConfigFormData) => {
    if (!stage) return

    onSave(stage.id, {
      name: data.name,
      description: data.description,
      type: data.type,
      channels: [...data.channels, ...(data.customChannels || [])],
      contentTypes: [...data.contentTypes, ...(data.customContentTypes || [])],
      isConfigured: true,
    })
    onClose()
  }

  const addCustomChannel = () => {
    if (newChannel.trim()) {
      const currentCustom = form.getValues("customChannels") || []
      form.setValue("customChannels", [...currentCustom, newChannel.trim()])
      setNewChannel("")
    }
  }

  const removeCustomChannel = (index: number) => {
    const currentCustom = form.getValues("customChannels") || []
    form.setValue("customChannels", currentCustom.filter((_, i) => i !== index))
  }

  const addCustomContentType = () => {
    if (newContentType.trim()) {
      const currentCustom = form.getValues("customContentTypes") || []
      form.setValue("customContentTypes", [...currentCustom, newContentType.trim()])
      setNewContentType("")
    }
  }

  const removeCustomContentType = (index: number) => {
    const currentCustom = form.getValues("customContentTypes") || []
    form.setValue("customContentTypes", currentCustom.filter((_, i) => i !== index))
  }

  const getStageTypeIcon = (type: JourneyStage["type"]) => {
    switch (type) {
      case "awareness":
        return <Users className="h-4 w-4" />
      case "consideration":
        return <FileText className="h-4 w-4" />
      case "conversion":
        return <Target className="h-4 w-4" />
      case "retention":
        return <Mail className="h-4 w-4" />
    }
  }

  if (!stage) return null

  return (
    <Sheet open={isOpen} onOpenChange={onClose}>
      <SheetContent className="w-full sm:max-w-2xl overflow-y-auto">
        <SheetHeader>
          <SheetTitle className="flex items-center gap-2">
            {getStageTypeIcon(stage.type)}
            Configure Stage: {stage.name}
          </SheetTitle>
          <SheetDescription>
            Customize your {stage.type} stage with specific channels, content types, and messaging guidance.
          </SheetDescription>
        </SheetHeader>

        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6 mt-6">
            <Tabs defaultValue="basics" className="w-full">
              <TabsList className="grid w-full grid-cols-3">
                <TabsTrigger value="basics">Basics</TabsTrigger>
                <TabsTrigger value="channels">Channels & Content</TabsTrigger>
                <TabsTrigger value="guidance">Guidance</TabsTrigger>
              </TabsList>

              <TabsContent value="basics" className="space-y-4">
                <FormField
                  control={form.control}
                  name="name"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Stage Name</FormLabel>
                      <FormControl>
                        <Input placeholder="Enter stage name" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />

                <FormField
                  control={form.control}
                  name="description"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Description</FormLabel>
                      <FormControl>
                        <Textarea
                          placeholder="Describe the purpose and goals of this stage"
                          className="resize-none"
                          {...field}
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />

                <FormField
                  control={form.control}
                  name="type"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Stage Type</FormLabel>
                      <Select onValueChange={field.onChange} defaultValue={field.value}>
                        <FormControl>
                          <SelectTrigger>
                            <SelectValue placeholder="Select stage type" />
                          </SelectTrigger>
                        </FormControl>
                        <SelectContent>
                          <SelectItem value="awareness">Awareness</SelectItem>
                          <SelectItem value="consideration">Consideration</SelectItem>
                          <SelectItem value="conversion">Conversion</SelectItem>
                          <SelectItem value="retention">Retention</SelectItem>
                        </SelectContent>
                      </Select>
                      <FormMessage />
                    </FormItem>
                  )}
                />

                <FormField
                  control={form.control}
                  name="targetAudience"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Target Audience</FormLabel>
                      <FormControl>
                        <Textarea
                          placeholder="Describe your target audience for this stage"
                          className="resize-none"
                          {...field}
                        />
                      </FormControl>
                      <FormDescription>
                        Who are you trying to reach at this stage of their journey?
                      </FormDescription>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </TabsContent>

              <TabsContent value="channels" className="space-y-6">
                {/* Channel Selection */}
                <div className="space-y-4">
                  <div className="flex items-center gap-2">
                    <h3 className="text-lg font-semibold">Marketing Channels</h3>
                    <Badge variant="secondary" className="text-xs">
                      {currentChannels.length} selected
                    </Badge>
                  </div>

                  {/* Recommended Channels */}
                  <div className="space-y-3">
                    <div className="flex items-center gap-2 text-sm text-gray-600">
                      <Lightbulb className="h-4 w-4" />
                      Recommended for {currentType} stage:
                    </div>
                    <div className="grid grid-cols-2 gap-2">
                      {recommendations.channels.map((channel) => (
                        <FormField
                          key={channel}
                          control={form.control}
                          name="channels"
                          render={({ field }) => (
                            <FormItem className="flex items-center space-x-3 space-y-0">
                              <FormControl>
                                <Checkbox
                                  checked={field.value?.includes(channel)}
                                  onCheckedChange={(checked) => {
                                    return checked
                                      ? field.onChange([...field.value, channel])
                                      : field.onChange(field.value?.filter((value) => value !== channel))
                                  }}
                                />
                              </FormControl>
                              <FormLabel className="text-sm font-normal cursor-pointer">
                                {channel}
                              </FormLabel>
                            </FormItem>
                          )}
                        />
                      ))}
                    </div>
                  </div>

                  {/* Custom Channels */}
                  <div className="space-y-3">
                    <div className="flex items-center gap-2">
                      <Input
                        placeholder="Add custom channel"
                        value={newChannel}
                        onChange={(e) => setNewChannel(e.target.value)}
                        onKeyPress={(e) => e.key === "Enter" && (e.preventDefault(), addCustomChannel())}
                      />
                      <Button type="button" onClick={addCustomChannel} size="sm">
                        <Plus className="h-4 w-4" />
                      </Button>
                    </div>
                    {form.watch("customChannels")?.map((channel, index) => (
                      <div key={index} className="flex items-center gap-2">
                        <Badge variant="outline" className="flex items-center gap-1">
                          {channel}
                          <button type="button" onClick={() => removeCustomChannel(index)}>
                            <X className="h-3 w-3" />
                          </button>
                        </Badge>
                      </div>
                    ))}
                  </div>
                </div>

                <Separator />

                {/* Content Type Selection */}
                <div className="space-y-4">
                  <div className="flex items-center gap-2">
                    <h3 className="text-lg font-semibold">Content Types</h3>
                    <Badge variant="secondary" className="text-xs">
                      {currentContentTypes.length} selected
                    </Badge>
                  </div>

                  {/* Recommended Content Types */}
                  <div className="space-y-3">
                    <div className="flex items-center gap-2 text-sm text-gray-600">
                      <Lightbulb className="h-4 w-4" />
                      Recommended for {currentType} stage:
                    </div>
                    <div className="grid grid-cols-2 gap-2">
                      {recommendations.contentTypes.map((contentType) => (
                        <FormField
                          key={contentType}
                          control={form.control}
                          name="contentTypes"
                          render={({ field }) => (
                            <FormItem className="flex items-center space-x-3 space-y-0">
                              <FormControl>
                                <Checkbox
                                  checked={field.value?.includes(contentType)}
                                  onCheckedChange={(checked) => {
                                    return checked
                                      ? field.onChange([...field.value, contentType])
                                      : field.onChange(field.value?.filter((value) => value !== contentType))
                                  }}
                                />
                              </FormControl>
                              <FormLabel className="text-sm font-normal cursor-pointer">
                                {contentType}
                              </FormLabel>
                            </FormItem>
                          )}
                        />
                      ))}
                    </div>
                  </div>

                  {/* Custom Content Types */}
                  <div className="space-y-3">
                    <div className="flex items-center gap-2">
                      <Input
                        placeholder="Add custom content type"
                        value={newContentType}
                        onChange={(e) => setNewContentType(e.target.value)}
                        onKeyPress={(e) => e.key === "Enter" && (e.preventDefault(), addCustomContentType())}
                      />
                      <Button type="button" onClick={addCustomContentType} size="sm">
                        <Plus className="h-4 w-4" />
                      </Button>
                    </div>
                    {form.watch("customContentTypes")?.map((contentType, index) => (
                      <div key={index} className="flex items-center gap-2">
                        <Badge variant="outline" className="flex items-center gap-1">
                          {contentType}
                          <button type="button" onClick={() => removeCustomContentType(index)}>
                            <X className="h-3 w-3" />
                          </button>
                        </Badge>
                      </div>
                    ))}
                  </div>
                </div>
              </TabsContent>

              <TabsContent value="guidance" className="space-y-6">
                {/* Messaging Tips */}
                <Card>
                  <CardHeader>
                    <CardTitle className="flex items-center gap-2 text-lg">
                      <Info className="h-5 w-5" />
                      Messaging Tips for {currentType.charAt(0).toUpperCase() + currentType.slice(1)}
                    </CardTitle>
                    <CardDescription>
                      Best practices for messaging at this stage
                    </CardDescription>
                  </CardHeader>
                  <CardContent>
                    <ul className="space-y-2">
                      {recommendations.messagingTips.map((tip, index) => (
                        <li key={index} className="flex items-start gap-2 text-sm">
                          <CheckCircle className="h-4 w-4 text-green-500 mt-0.5 flex-shrink-0" />
                          {tip}
                        </li>
                      ))}
                    </ul>
                  </CardContent>
                </Card>

                {/* Custom Messaging Guidance */}
                <FormField
                  control={form.control}
                  name="messagingGuidance"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Custom Messaging Guidance</FormLabel>
                      <FormControl>
                        <Textarea
                          placeholder="Add specific messaging guidance for your team"
                          className="min-h-[100px] resize-none"
                          {...field}
                        />
                      </FormControl>
                      <FormDescription>
                        Provide specific guidance on tone, messaging, and key points for this stage.
                      </FormDescription>
                      <FormMessage />
                    </FormItem>
                  )}
                />

                {/* KPI Selection */}
                <div className="space-y-4">
                  <h3 className="text-lg font-semibold">Key Performance Indicators (KPIs)</h3>
                  <div className="grid grid-cols-2 gap-2">
                    {recommendations.kpis.map((kpi) => (
                      <FormField
                        key={kpi}
                        control={form.control}
                        name="kpis"
                        render={({ field }) => (
                          <FormItem className="flex items-center space-x-3 space-y-0">
                            <FormControl>
                              <Checkbox
                                checked={field.value?.includes(kpi)}
                                onCheckedChange={(checked) => {
                                  return checked
                                    ? field.onChange([...(field.value || []), kpi])
                                    : field.onChange(field.value?.filter((value) => value !== kpi))
                                }}
                              />
                            </FormControl>
                            <FormLabel className="text-sm font-normal cursor-pointer">
                              {kpi}
                            </FormLabel>
                          </FormItem>
                        )}
                      />
                    ))}
                  </div>
                </div>
              </TabsContent>
            </Tabs>

            <Separator />

            <div className="flex justify-between pt-4">
              <Button type="button" variant="outline" onClick={onClose}>
                Cancel
              </Button>
              <Button type="submit">
                Save Configuration
              </Button>
            </div>
          </form>
        </Form>
      </SheetContent>
    </Sheet>
  )
}