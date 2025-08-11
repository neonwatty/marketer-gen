"use client"

import * as React from "react"
import { UseFormReturn } from "react-hook-form"
import { FormField, FormItem, FormLabel, FormControl, FormDescription, FormMessage } from "@/components/ui/form"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Checkbox } from "@/components/ui/checkbox"
import { Badge } from "@/components/ui/badge"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { type CampaignWizardData } from "../campaign-wizard-schemas"

interface AudienceChannelsStepProps {
  form: UseFormReturn<CampaignWizardData>
}

const channelOptions = {
  'email': { label: 'Email Marketing', icon: '📧', description: 'Newsletters, automated sequences' },
  'social-media': { label: 'Social Media', icon: '📱', description: 'Facebook, Instagram, Twitter, LinkedIn' },
  'blog': { label: 'Blog Content', icon: '📝', description: 'Website blog posts and articles' },
  'display-ads': { label: 'Display Advertising', icon: '🖼️', description: 'Banner ads, retargeting campaigns' },
  'search-ads': { label: 'Search Advertising', icon: '🔍', description: 'Google Ads, Bing Ads' },
  'influencer': { label: 'Influencer Marketing', icon: '🌟', description: 'Partnerships with content creators' },
  'webinar': { label: 'Webinars', icon: '🎥', description: 'Live and recorded presentations' },
  'direct-mail': { label: 'Direct Mail', icon: '📮', description: 'Physical mail campaigns' },
  'sms': { label: 'SMS Marketing', icon: '💬', description: 'Text message campaigns' },
} as const

const toneOptions = {
  'professional': 'Professional',
  'casual': 'Casual',
  'friendly': 'Friendly',
  'persuasive': 'Persuasive',
  'informative': 'Informative',
  'urgent': 'Urgent',
} as const

const ageRangeOptions = [
  '18-24', '25-34', '35-44', '45-54', '55-64', '65+'
] as const

const genderOptions = [
  { value: 'all', label: 'All Genders' },
  { value: 'male', label: 'Male' },
  { value: 'female', label: 'Female' },
  { value: 'non-binary', label: 'Non-binary' },
] as const

export function AudienceChannelsStep({ form }: AudienceChannelsStepProps) {
  const selectedChannels = form.watch("audienceChannels.channels") || []

  const handleChannelChange = (channel: string, checked: boolean) => {
    const current = selectedChannels
    if (checked) {
      form.setValue("audienceChannels.channels", [...current, channel] as any)
    } else {
      form.setValue("audienceChannels.channels", current.filter(ch => ch !== channel) as any)
    }
  }

  return (
    <div className="space-y-8">
      {/* Target Audience Demographics */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg">Target Audience Demographics</CardTitle>
          <CardDescription>
            Define the demographic characteristics of your target audience
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <FormField
              control={form.control}
              name="audienceChannels.targetAudience.demographics.ageRange"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Age Range (Optional)</FormLabel>
                  <Select onValueChange={field.onChange} value={field.value}>
                    <FormControl>
                      <SelectTrigger>
                        <SelectValue placeholder="Select age range" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      {ageRangeOptions.map((range) => (
                        <SelectItem key={range} value={range}>
                          {range} years old
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="audienceChannels.targetAudience.demographics.gender"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Gender (Optional)</FormLabel>
                  <Select onValueChange={field.onChange} value={field.value}>
                    <FormControl>
                      <SelectTrigger>
                        <SelectValue placeholder="Select gender" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      {genderOptions.map((option) => (
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
          </div>

          <FormField
            control={form.control}
            name="audienceChannels.targetAudience.demographics.location"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Geographic Location (Optional)</FormLabel>
                <FormControl>
                  <Input
                    placeholder="e.g., United States, California, San Francisco Bay Area"
                    {...field}
                  />
                </FormControl>
                <FormDescription>
                  Specify countries, states, cities, or regions
                </FormDescription>
                <FormMessage />
              </FormItem>
            )}
          />

          <FormField
            control={form.control}
            name="audienceChannels.targetAudience.customDescription"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Detailed Audience Description</FormLabel>
                <FormControl>
                  <Textarea
                    placeholder="Describe your target audience in detail: their interests, pain points, behaviors, motivations..."
                    rows={4}
                    {...field}
                  />
                </FormControl>
                <FormDescription>
                  Provide a comprehensive description of your ideal customer or audience
                </FormDescription>
                <FormMessage />
              </FormItem>
            )}
          />
        </CardContent>
      </Card>

      {/* Marketing Channels */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg">Marketing Channels</CardTitle>
          <CardDescription>
            Select the channels where you'll promote your campaign
          </CardDescription>
        </CardHeader>
        <CardContent>
          <FormField
            control={form.control}
            name="audienceChannels.channels"
            render={() => (
              <FormItem>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                  {Object.entries(channelOptions).map(([value, channel]) => (
                    <div
                      key={value}
                      className={`border rounded-lg p-4 cursor-pointer transition-all hover:shadow-md ${
                        selectedChannels.includes(value)
                          ? "ring-2 ring-primary border-primary bg-primary/5"
                          : "border-muted"
                      }`}
                      onClick={() => 
                        handleChannelChange(value, !selectedChannels.includes(value))
                      }
                    >
                      <div className="flex items-start space-x-3">
                        <div className="text-xl flex-shrink-0">
                          {channel.icon}
                        </div>
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center space-x-2">
                            <Checkbox
                              checked={selectedChannels.includes(value)}
                              onChange={() => {}}
                              className="pointer-events-none"
                            />
                            <h4 className="font-medium text-sm">
                              {channel.label}
                            </h4>
                          </div>
                          <p className="text-xs text-muted-foreground mt-1">
                            {channel.description}
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

          {/* Show selected channels */}
          {selectedChannels.length > 0 && (
            <div className="mt-6">
              <p className="text-sm text-muted-foreground mb-2">Selected channels:</p>
              <div className="flex flex-wrap gap-2">
                {selectedChannels.map((channel) => (
                  <Badge key={channel} variant="secondary">
                    {channelOptions[channel as keyof typeof channelOptions]?.icon} {channelOptions[channel as keyof typeof channelOptions]?.label}
                  </Badge>
                ))}
              </div>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Tone and Messaging */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg">Tone & Messaging</CardTitle>
          <CardDescription>
            Define the voice and style for your campaign communications
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <FormField
            control={form.control}
            name="audienceChannels.tone"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Communication Tone</FormLabel>
                <Select onValueChange={field.onChange} value={field.value}>
                  <FormControl>
                    <SelectTrigger>
                      <SelectValue placeholder="Select tone" />
                    </SelectTrigger>
                  </FormControl>
                  <SelectContent>
                    {Object.entries(toneOptions).map(([value, label]) => (
                      <SelectItem key={value} value={value}>
                        {label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <FormDescription>
                  Choose the tone that best fits your brand and audience
                </FormDescription>
                <FormMessage />
              </FormItem>
            )}
          />

          <FormField
            control={form.control}
            name="audienceChannels.keywords"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Keywords (Optional)</FormLabel>
                <FormControl>
                  <Input
                    placeholder="e.g., sustainable fashion, eco-friendly, organic materials"
                    {...field}
                  />
                </FormControl>
                <FormDescription>
                  Enter relevant keywords or phrases separated by commas
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