"use client"

import * as React from "react"
import { UseFormReturn } from "react-hook-form"
import { format } from "date-fns"
import { CheckCircle, AlertCircle, Settings, Bell, Rocket } from "lucide-react"
import { FormField, FormItem, FormLabel, FormControl, FormDescription, FormMessage } from "@/components/ui/form"
import { Input } from "@/components/ui/input"
import { Checkbox } from "@/components/ui/checkbox"
import { Switch } from "@/components/ui/switch"
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group"
import { Label } from "@/components/ui/label"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Separator } from "@/components/ui/separator"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { 
  type CampaignWizardData,
  campaignTemplates
} from "../campaign-wizard-schemas"

interface ReviewFinalizationStepProps {
  form: UseFormReturn<CampaignWizardData>
}

export function ReviewFinalizationStep({ form }: ReviewFinalizationStepProps) {
  const formData = form.watch()
  const agreedToTerms = form.watch("reviewFinalization.campaignReview.agreedToTerms")
  const launchPreference = form.watch("reviewFinalization.campaignReview.launchPreference")

  // Helper function to format currency
  const formatCurrency = (amount: number, currency: string) => {
    const symbols = { USD: '$', EUR: '€', GBP: '£', CAD: 'C$' }
    const symbol = symbols[currency as keyof typeof symbols] || '$'
    return `${symbol}${amount.toLocaleString()}`
  }

  // Calculate campaign duration
  const campaignDuration = React.useMemo(() => {
    if (formData.budgetSchedule.schedule.startDate && formData.budgetSchedule.schedule.endDate) {
      const diffTime = Math.abs(
        formData.budgetSchedule.schedule.endDate.getTime() - 
        formData.budgetSchedule.schedule.startDate.getTime()
      )
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))
      return diffDays
    }
    return 0
  }, [formData.budgetSchedule.schedule])

  const selectedTemplate = formData.basics.template 
    ? campaignTemplates[formData.basics.template] 
    : null

  return (
    <div className="space-y-8">
      {/* Campaign Summary */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg flex items-center gap-2">
            <CheckCircle className="h-5 w-5 text-green-600" />
            Campaign Summary
          </CardTitle>
          <CardDescription>
            Review your campaign configuration before launch
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          {/* Basic Information */}
          <div>
            <h4 className="font-medium text-sm mb-3">Basic Information</h4>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
              <div>
                <span className="text-muted-foreground">Campaign Name:</span>
                <p className="font-medium">{formData.basics.name || 'Not specified'}</p>
              </div>
              <div>
                <span className="text-muted-foreground">Template:</span>
                <p className="font-medium">
                  {selectedTemplate ? `${selectedTemplate.icon} ${selectedTemplate.name}` : 'Blank Campaign'}
                </p>
              </div>
            </div>
            
            {formData.basics.description && (
              <div className="mt-4">
                <span className="text-muted-foreground text-sm">Description:</span>
                <p className="text-sm mt-1">{formData.basics.description}</p>
              </div>
            )}

            {formData.basics.objectives.length > 0 && (
              <div className="mt-4">
                <span className="text-muted-foreground text-sm">Objectives:</span>
                <div className="flex flex-wrap gap-2 mt-1">
                  {formData.basics.objectives.map((objective) => (
                    <Badge key={objective} variant="secondary" className="text-xs">
                      {objective.replace('-', ' ').replace(/\b\w/g, l => l.toUpperCase())}
                    </Badge>
                  ))}
                </div>
              </div>
            )}
          </div>

          <Separator />

          {/* Audience & Channels */}
          <div>
            <h4 className="font-medium text-sm mb-3">Target Audience & Channels</h4>
            <div className="space-y-3 text-sm">
              <div>
                <span className="text-muted-foreground">Tone:</span>
                <span className="ml-2 font-medium capitalize">
                  {formData.audienceChannels.tone.replace('-', ' ')}
                </span>
              </div>
              
              {formData.audienceChannels.channels.length > 0 && (
                <div>
                  <span className="text-muted-foreground">Channels:</span>
                  <div className="flex flex-wrap gap-2 mt-1">
                    {formData.audienceChannels.channels.map((channel) => (
                      <Badge key={channel} variant="outline" className="text-xs">
                        {channel.replace('-', ' ').replace(/\b\w/g, l => l.toUpperCase())}
                      </Badge>
                    ))}
                  </div>
                </div>
              )}

              {formData.audienceChannels.targetAudience.customDescription && (
                <div>
                  <span className="text-muted-foreground">Audience Description:</span>
                  <p className="mt-1 text-xs">
                    {formData.audienceChannels.targetAudience.customDescription}
                  </p>
                </div>
              )}
            </div>
          </div>

          <Separator />

          {/* Budget & Schedule */}
          <div>
            <h4 className="font-medium text-sm mb-3">Budget & Schedule</h4>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
              <div>
                <span className="text-muted-foreground">Total Budget:</span>
                <p className="font-medium text-lg">
                  {formatCurrency(
                    formData.budgetSchedule.budget.total,
                    formData.budgetSchedule.budget.currency
                  )}
                </p>
              </div>
              <div>
                <span className="text-muted-foreground">Duration:</span>
                <p className="font-medium">
                  {campaignDuration} day{campaignDuration !== 1 ? 's' : ''}
                </p>
              </div>
              <div>
                <span className="text-muted-foreground">Start Date:</span>
                <p className="font-medium">
                  {formData.budgetSchedule.schedule.launchImmediately 
                    ? 'Immediate' 
                    : format(formData.budgetSchedule.schedule.startDate, 'PPP')
                  }
                </p>
              </div>
              <div>
                <span className="text-muted-foreground">End Date:</span>
                <p className="font-medium">
                  {format(formData.budgetSchedule.schedule.endDate, 'PPP')}
                </p>
              </div>
            </div>
          </div>

          <Separator />

          {/* Content Strategy */}
          <div>
            <h4 className="font-medium text-sm mb-3">Content Strategy</h4>
            <div className="space-y-3 text-sm">
              <div>
                <span className="text-muted-foreground">Content Frequency:</span>
                <span className="ml-2 font-medium capitalize">
                  {formData.contentAssets.contentStrategy.contentFrequency}
                </span>
              </div>

              {formData.contentAssets.contentStrategy.contentTypes.length > 0 && (
                <div>
                  <span className="text-muted-foreground">Content Types:</span>
                  <div className="flex flex-wrap gap-2 mt-1">
                    {formData.contentAssets.contentStrategy.contentTypes.map((type) => (
                      <Badge key={type} variant="outline" className="text-xs">
                        {type.replace('-', ' ').replace(/\b\w/g, l => l.toUpperCase())}
                      </Badge>
                    ))}
                  </div>
                </div>
              )}

              {formData.contentAssets.messaging.primaryMessage && (
                <div>
                  <span className="text-muted-foreground">Primary Message:</span>
                  <p className="mt-1 text-xs">
                    {formData.contentAssets.messaging.primaryMessage}
                  </p>
                </div>
              )}

              {formData.contentAssets.messaging.callToAction && (
                <div>
                  <span className="text-muted-foreground">Call to Action:</span>
                  <span className="ml-2 font-medium">
                    "{formData.contentAssets.messaging.callToAction}"
                  </span>
                </div>
              )}
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Launch Options */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg flex items-center gap-2">
            <Rocket className="h-5 w-5 text-blue-600" />
            Launch Preferences
          </CardTitle>
          <CardDescription>
            Choose how you want to launch your campaign
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <FormField
            control={form.control}
            name="reviewFinalization.campaignReview.launchPreference"
            render={({ field }) => (
              <FormItem className="space-y-3">
                <FormControl>
                  <RadioGroup
                    onValueChange={field.onChange}
                    value={field.value}
                    className="grid grid-cols-1 gap-4"
                  >
                    <div className="flex items-center space-x-3 border rounded-lg p-4">
                      <RadioGroupItem value="immediate" id="immediate" />
                      <div className="grid gap-1.5 leading-none">
                        <Label htmlFor="immediate" className="text-sm font-medium">
                          Launch Immediately
                        </Label>
                        <p className="text-xs text-muted-foreground">
                          Start the campaign right away once created
                        </p>
                      </div>
                    </div>
                    <div className="flex items-center space-x-3 border rounded-lg p-4">
                      <RadioGroupItem value="scheduled" id="scheduled" />
                      <div className="grid gap-1.5 leading-none">
                        <Label htmlFor="scheduled" className="text-sm font-medium">
                          Launch on Schedule
                        </Label>
                        <p className="text-xs text-muted-foreground">
                          Wait until the scheduled start date to begin
                        </p>
                      </div>
                    </div>
                    <div className="flex items-center space-x-3 border rounded-lg p-4">
                      <RadioGroupItem value="draft" id="draft" />
                      <div className="grid gap-1.5 leading-none">
                        <Label htmlFor="draft" className="text-sm font-medium">
                          Save as Draft
                        </Label>
                        <p className="text-xs text-muted-foreground">
                          Save the campaign for review and manual launch later
                        </p>
                      </div>
                    </div>
                  </RadioGroup>
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
        </CardContent>
      </Card>

      {/* Notifications */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg flex items-center gap-2">
            <Bell className="h-5 w-5 text-orange-600" />
            Notification Settings
          </CardTitle>
          <CardDescription>
            Configure how you'll receive updates about this campaign
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <FormField
            control={form.control}
            name="reviewFinalization.campaignReview.notifications.emailNotifications"
            render={({ field }) => (
              <FormItem className="flex flex-row items-center justify-between rounded-lg border p-4">
                <div className="space-y-0.5">
                  <FormLabel className="text-sm font-medium">Email Notifications</FormLabel>
                  <FormDescription className="text-xs">
                    Receive campaign updates and performance reports via email
                  </FormDescription>
                </div>
                <FormControl>
                  <Switch
                    checked={field.value}
                    onCheckedChange={field.onChange}
                  />
                </FormControl>
              </FormItem>
            )}
          />

          <FormField
            control={form.control}
            name="reviewFinalization.campaignReview.notifications.slackNotifications"
            render={({ field }) => (
              <FormItem className="flex flex-row items-center justify-between rounded-lg border p-4">
                <div className="space-y-0.5">
                  <FormLabel className="text-sm font-medium">Slack Notifications</FormLabel>
                  <FormDescription className="text-xs">
                    Get campaign alerts in your Slack workspace
                  </FormDescription>
                </div>
                <FormControl>
                  <Switch
                    checked={field.value}
                    onCheckedChange={field.onChange}
                  />
                </FormControl>
              </FormItem>
            )}
          />

          <FormField
            control={form.control}
            name="reviewFinalization.campaignReview.notifications.webhookUrl"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Webhook URL (Optional)</FormLabel>
                <FormControl>
                  <Input
                    type="url"
                    placeholder="https://your-app.com/webhook/campaigns"
                    {...field}
                  />
                </FormControl>
                <FormDescription className="text-xs">
                  Send campaign events to your application via webhook
                </FormDescription>
                <FormMessage />
              </FormItem>
            )}
          />
        </CardContent>
      </Card>

      {/* Terms and Conditions */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg flex items-center gap-2">
            <Settings className="h-5 w-5 text-gray-600" />
            Final Review
          </CardTitle>
        </CardHeader>
        <CardContent>
          <FormField
            control={form.control}
            name="reviewFinalization.campaignReview.agreedToTerms"
            render={({ field }) => (
              <FormItem className="flex flex-row items-start space-x-3 space-y-0">
                <FormControl>
                  <Checkbox
                    checked={field.value}
                    onCheckedChange={field.onChange}
                  />
                </FormControl>
                <div className="space-y-1 leading-none">
                  <FormLabel className="text-sm font-medium">
                    I agree to the terms and conditions
                  </FormLabel>
                  <FormDescription className="text-xs">
                    By checking this box, you confirm that you have reviewed all campaign settings 
                    and agree to our terms of service and privacy policy.
                  </FormDescription>
                </div>
              </FormItem>
            )}
          />
          <FormMessage />

          {!agreedToTerms && (
            <Alert className="mt-4">
              <AlertCircle className="h-4 w-4" />
              <AlertDescription className="text-xs">
                You must agree to the terms and conditions before proceeding.
              </AlertDescription>
            </Alert>
          )}

          {launchPreference === 'immediate' && agreedToTerms && (
            <Alert className="mt-4">
              <Rocket className="h-4 w-4" />
              <AlertDescription className="text-xs">
                <strong>Ready for launch!</strong> Your campaign will start immediately after creation.
              </AlertDescription>
            </Alert>
          )}
        </CardContent>
      </Card>
    </div>
  )
}