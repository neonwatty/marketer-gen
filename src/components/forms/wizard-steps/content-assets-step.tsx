"use client"

import * as React from "react"
import { UseFormReturn } from "react-hook-form"
import { FileText, Image, Palette, MessageSquare } from "lucide-react"
import { FormField, FormItem, FormLabel, FormControl, FormDescription, FormMessage } from "@/components/ui/form"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Checkbox } from "@/components/ui/checkbox"
import { Badge } from "@/components/ui/badge"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { type CampaignWizardData } from "../campaign-wizard-schemas"

interface ContentAssetsStepProps {
  form: UseFormReturn<CampaignWizardData>
}

const contentTypeOptions = {
  'blog-post': { label: 'Blog Posts', icon: '📝', description: 'Long-form articles and educational content' },
  'social-post': { label: 'Social Posts', icon: '📱', description: 'Social media updates and engagement posts' },
  'email-newsletter': { label: 'Email Newsletter', icon: '📧', description: 'Email campaigns and newsletters' },
  'landing-page': { label: 'Landing Pages', icon: '🔗', description: 'Conversion-focused landing pages' },
  'video-script': { label: 'Video Scripts', icon: '🎬', description: 'Scripts for video content and ads' },
  'ad-copy': { label: 'Ad Copy', icon: '🎯', description: 'Paid advertising copy and creatives' },
  'infographic': { label: 'Infographics', icon: '📊', description: 'Visual data and information graphics' },
  'case-study': { label: 'Case Studies', icon: '📈', description: 'Customer success stories and testimonials' },
} as const

const frequencyOptions = {
  'daily': 'Daily',
  'weekly': 'Weekly',
  'bi-weekly': 'Bi-weekly',
  'monthly': 'Monthly',
} as const

export function ContentAssetsStep({ form }: ContentAssetsStepProps) {
  const selectedContentTypes = form.watch("contentAssets.contentStrategy.contentTypes") || []
  const brandColors = form.watch("contentAssets.assets.brandColors") || []

  const handleContentTypeChange = (contentType: string, checked: boolean) => {
    const current = selectedContentTypes
    if (checked) {
      form.setValue("contentAssets.contentStrategy.contentTypes", [...current, contentType] as any)
    } else {
      form.setValue("contentAssets.contentStrategy.contentTypes", current.filter(type => type !== contentType) as any)
    }
  }

  const handleAddBrandColor = () => {
    const newColor = "#000000"
    form.setValue("contentAssets.assets.brandColors", [...brandColors, newColor])
  }

  const handleRemoveBrandColor = (index: number) => {
    const updated = brandColors.filter((_, i) => i !== index)
    form.setValue("contentAssets.assets.brandColors", updated)
  }

  const handleColorChange = (index: number, color: string) => {
    const updated = [...brandColors]
    updated[index] = color
    form.setValue("contentAssets.assets.brandColors", updated)
  }

  return (
    <div className="space-y-8">
      {/* Content Strategy */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg flex items-center gap-2">
            <FileText className="h-5 w-5" />
            Content Strategy
          </CardTitle>
          <CardDescription>
            Define what types of content you'll create and how often
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <FormField
            control={form.control}
            name="contentAssets.contentStrategy.contentTypes"
            render={() => (
              <FormItem>
                <FormLabel>Content Types</FormLabel>
                <FormDescription>
                  Select the types of content you plan to create for this campaign
                </FormDescription>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
                  {Object.entries(contentTypeOptions).map(([value, content]) => (
                    <div
                      key={value}
                      className={`border rounded-lg p-4 cursor-pointer transition-all hover:shadow-md ${
                        selectedContentTypes.includes(value)
                          ? "ring-2 ring-primary border-primary bg-primary/5"
                          : "border-muted"
                      }`}
                      onClick={() => 
                        handleContentTypeChange(value, !selectedContentTypes.includes(value))
                      }
                    >
                      <div className="flex items-start space-x-3">
                        <div className="text-xl flex-shrink-0">
                          {content.icon}
                        </div>
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center space-x-2">
                            <Checkbox
                              checked={selectedContentTypes.includes(value)}
                              onChange={() => {}}
                              className="pointer-events-none"
                            />
                            <h4 className="font-medium text-sm">
                              {content.label}
                            </h4>
                          </div>
                          <p className="text-xs text-muted-foreground mt-1">
                            {content.description}
                          </p>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
                <FormMessage />
              </FormItem>
            )}
          />

          {/* Show selected content types */}
          {selectedContentTypes.length > 0 && (
            <div className="mt-4">
              <p className="text-sm text-muted-foreground mb-2">Selected content types:</p>
              <div className="flex flex-wrap gap-2">
                {selectedContentTypes.map((type) => (
                  <Badge key={type} variant="secondary">
                    {contentTypeOptions[type as keyof typeof contentTypeOptions]?.icon} {contentTypeOptions[type as keyof typeof contentTypeOptions]?.label}
                  </Badge>
                ))}
              </div>
            </div>
          )}

          <FormField
            control={form.control}
            name="contentAssets.contentStrategy.contentFrequency"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Content Frequency</FormLabel>
                <Select onValueChange={field.onChange} value={field.value}>
                  <FormControl>
                    <SelectTrigger>
                      <SelectValue placeholder="Select frequency" />
                    </SelectTrigger>
                  </FormControl>
                  <SelectContent>
                    {Object.entries(frequencyOptions).map(([value, label]) => (
                      <SelectItem key={value} value={value}>
                        {label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <FormDescription>
                  How often do you plan to publish new content?
                </FormDescription>
                <FormMessage />
              </FormItem>
            )}
          />

          <FormField
            control={form.control}
            name="contentAssets.contentStrategy.brandGuidelines"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Brand Guidelines (Optional)</FormLabel>
                <FormControl>
                  <Textarea
                    placeholder="Describe your brand voice, style preferences, dos and don'ts..."
                    rows={3}
                    {...field}
                  />
                </FormControl>
                <FormDescription>
                  Provide any specific brand guidelines for content creation
                </FormDescription>
                <FormMessage />
              </FormItem>
            )}
          />
        </CardContent>
      </Card>

      {/* Brand Assets */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg flex items-center gap-2">
            <Image className="h-5 w-5" />
            Brand Assets
          </CardTitle>
          <CardDescription>
            Upload or specify your brand assets for consistent visual identity
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <FormField
            control={form.control}
            name="contentAssets.assets.logoUrl"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Logo URL (Optional)</FormLabel>
                <FormControl>
                  <Input
                    type="url"
                    placeholder="https://example.com/logo.png"
                    {...field}
                  />
                </FormControl>
                <FormDescription>
                  URL to your brand logo for use in content
                </FormDescription>
                <FormMessage />
              </FormItem>
            )}
          />

          <div>
            <FormLabel>Brand Colors (Optional)</FormLabel>
            <FormDescription className="mb-4">
              Add your brand colors for consistent visual identity
            </FormDescription>
            
            <div className="space-y-3">
              {brandColors.map((color, index) => (
                <div key={index} className="flex items-center gap-3">
                  <input
                    type="color"
                    value={color}
                    onChange={(e) => handleColorChange(index, e.target.value)}
                    className="w-12 h-10 border border-input rounded cursor-pointer"
                  />
                  <Input
                    value={color}
                    onChange={(e) => handleColorChange(index, e.target.value)}
                    placeholder="#000000"
                    className="font-mono text-sm"
                  />
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    onClick={() => handleRemoveBrandColor(index)}
                  >
                    Remove
                  </Button>
                </div>
              ))}
              
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={handleAddBrandColor}
                className="flex items-center gap-2"
              >
                <Palette className="h-4 w-4" />
                Add Color
              </Button>
            </div>
          </div>

          <FormField
            control={form.control}
            name="contentAssets.assets.fonts"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Brand Fonts (Optional)</FormLabel>
                <FormControl>
                  <Input
                    placeholder="e.g., Roboto, Open Sans, Montserrat"
                    {...field}
                    onChange={(e) => field.onChange(e.target.value.split(',').map(f => f.trim()).filter(Boolean))}
                  />
                </FormControl>
                <FormDescription>
                  Enter font names separated by commas
                </FormDescription>
                <FormMessage />
              </FormItem>
            )}
          />
        </CardContent>
      </Card>

      {/* Messaging */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg flex items-center gap-2">
            <MessageSquare className="h-5 w-5" />
            Core Messaging
          </CardTitle>
          <CardDescription>
            Define the key messages and calls-to-action for your campaign
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <FormField
            control={form.control}
            name="contentAssets.messaging.primaryMessage"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Primary Message</FormLabel>
                <FormControl>
                  <Textarea
                    placeholder="What's the main message you want to communicate in this campaign?"
                    rows={3}
                    {...field}
                  />
                </FormControl>
                <FormDescription>
                  The core message that will be consistent across all content
                </FormDescription>
                <FormMessage />
              </FormItem>
            )}
          />

          <FormField
            control={form.control}
            name="contentAssets.messaging.callToAction"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Call to Action</FormLabel>
                <FormControl>
                  <Input
                    placeholder="e.g., Shop Now, Learn More, Get Started, Sign Up"
                    {...field}
                  />
                </FormControl>
                <FormDescription>
                  The primary action you want your audience to take
                </FormDescription>
                <FormMessage />
              </FormItem>
            )}
          />

          <FormField
            control={form.control}
            name="contentAssets.messaging.valueProposition"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Value Proposition (Optional)</FormLabel>
                <FormControl>
                  <Textarea
                    placeholder="Why should customers choose you? What unique value do you provide?"
                    rows={3}
                    {...field}
                  />
                </FormControl>
                <FormDescription>
                  Explain the unique benefits and value your offering provides
                </FormDescription>
                <FormMessage />
              </FormItem>
            )}
          />
        </CardContent>
      </Card>
    </div>
  )
}