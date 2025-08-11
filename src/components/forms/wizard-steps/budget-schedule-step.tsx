"use client"

import * as React from "react"
import { UseFormReturn } from "react-hook-form"
import { format } from "date-fns"
import { CalendarIcon, DollarSign, Clock, AlertCircle } from "lucide-react"
import { FormField, FormItem, FormLabel, FormControl, FormDescription, FormMessage } from "@/components/ui/form"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Switch } from "@/components/ui/switch"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Calendar } from "@/components/ui/calendar"
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { cn } from "@/lib/utils"
import { type CampaignWizardData } from "../campaign-wizard-schemas"

interface BudgetScheduleStepProps {
  form: UseFormReturn<CampaignWizardData>
}

const currencyOptions = [
  { value: 'USD', label: 'USD ($)', symbol: '$' },
  { value: 'EUR', label: 'EUR (€)', symbol: '€' },
  { value: 'GBP', label: 'GBP (£)', symbol: '£' },
  { value: 'CAD', label: 'CAD (C$)', symbol: 'C$' },
] as const

const timezoneOptions = [
  'UTC',
  'America/New_York',
  'America/Chicago',
  'America/Denver',
  'America/Los_Angeles',
  'Europe/London',
  'Europe/Paris',
  'Europe/Berlin',
  'Asia/Tokyo',
  'Asia/Shanghai',
  'Australia/Sydney',
] as const

export function BudgetScheduleStep({ form }: BudgetScheduleStepProps) {
  const watchedStartDate = form.watch("budgetSchedule.schedule.startDate")
  const watchedEndDate = form.watch("budgetSchedule.schedule.endDate")
  const watchedCurrency = form.watch("budgetSchedule.budget.currency") || 'USD'
  const watchedLaunchImmediately = form.watch("budgetSchedule.schedule.launchImmediately")

  const selectedChannels = form.watch("audienceChannels.channels") || []
  
  // Calculate campaign duration
  const campaignDuration = React.useMemo(() => {
    if (watchedStartDate && watchedEndDate) {
      const diffTime = Math.abs(watchedEndDate.getTime() - watchedStartDate.getTime())
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))
      return diffDays
    }
    return 0
  }, [watchedStartDate, watchedEndDate])

  const currencySymbol = currencyOptions.find(c => c.value === watchedCurrency)?.symbol || '$'

  // Set default start date to today if launching immediately
  React.useEffect(() => {
    if (watchedLaunchImmediately) {
      form.setValue("budgetSchedule.schedule.startDate", new Date())
    }
  }, [watchedLaunchImmediately, form])

  return (
    <div className="space-y-8">
      {/* Budget Section */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg flex items-center gap-2">
            <DollarSign className="h-5 w-5" />
            Campaign Budget
          </CardTitle>
          <CardDescription>
            Set your total campaign budget and currency
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <FormField
              control={form.control}
              name="budgetSchedule.budget.total"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Total Budget</FormLabel>
                  <div className="relative">
                    <span className="absolute left-3 top-1/2 transform -translate-y-1/2 text-muted-foreground">
                      {currencySymbol}
                    </span>
                    <FormControl>
                      <Input
                        type="number"
                        step="0.01"
                        min="0"
                        placeholder="0.00"
                        className="pl-8"
                        {...field}
                        onChange={(e) => field.onChange(parseFloat(e.target.value) || 0)}
                      />
                    </FormControl>
                  </div>
                  <FormDescription>
                    Enter the total budget for this campaign
                  </FormDescription>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="budgetSchedule.budget.currency"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Currency</FormLabel>
                  <Select onValueChange={field.onChange} value={field.value}>
                    <FormControl>
                      <SelectTrigger>
                        <SelectValue placeholder="Select currency" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      {currencyOptions.map((currency) => (
                        <SelectItem key={currency.value} value={currency.value}>
                          {currency.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />
          </div>

          {/* Budget allocation hint */}
          {selectedChannels.length > 1 && (
            <Alert>
              <AlertCircle className="h-4 w-4" />
              <AlertDescription>
                With {selectedChannels.length} channels selected, consider how you'll allocate your budget across different channels. You can set specific allocations later in the campaign setup.
              </AlertDescription>
            </Alert>
          )}
        </CardContent>
      </Card>

      {/* Schedule Section */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg flex items-center gap-2">
            <Clock className="h-5 w-5" />
            Campaign Schedule
          </CardTitle>
          <CardDescription>
            Set when your campaign will start and end
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          {/* Launch immediately toggle */}
          <FormField
            control={form.control}
            name="budgetSchedule.schedule.launchImmediately"
            render={({ field }) => (
              <FormItem className="flex flex-row items-center justify-between rounded-lg border p-4">
                <div className="space-y-0.5">
                  <FormLabel className="text-base">Launch Immediately</FormLabel>
                  <FormDescription>
                    Start the campaign as soon as it's created
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

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <FormField
              control={form.control}
              name="budgetSchedule.schedule.startDate"
              render={({ field }) => (
                <FormItem className="flex flex-col">
                  <FormLabel>Start Date</FormLabel>
                  <Popover>
                    <PopoverTrigger asChild>
                      <FormControl>
                        <Button
                          variant="outline"
                          disabled={watchedLaunchImmediately}
                          className={cn(
                            "w-full pl-3 text-left font-normal",
                            !field.value && "text-muted-foreground"
                          )}
                        >
                          {field.value ? (
                            format(field.value, "PPP")
                          ) : (
                            <span>Pick a date</span>
                          )}
                          <CalendarIcon className="ml-auto h-4 w-4 opacity-50" />
                        </Button>
                      </FormControl>
                    </PopoverTrigger>
                    <PopoverContent className="w-auto p-0" align="start">
                      <Calendar
                        mode="single"
                        selected={field.value}
                        onSelect={field.onChange}
                        disabled={(date) =>
                          watchedLaunchImmediately ? false : date < new Date()
                        }
                        initialFocus
                      />
                    </PopoverContent>
                  </Popover>
                  <FormDescription>
                    {watchedLaunchImmediately 
                      ? "Will be set to today when launched"
                      : "When the campaign should begin"
                    }
                  </FormDescription>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="budgetSchedule.schedule.endDate"
              render={({ field }) => (
                <FormItem className="flex flex-col">
                  <FormLabel>End Date</FormLabel>
                  <Popover>
                    <PopoverTrigger asChild>
                      <FormControl>
                        <Button
                          variant="outline"
                          className={cn(
                            "w-full pl-3 text-left font-normal",
                            !field.value && "text-muted-foreground"
                          )}
                        >
                          {field.value ? (
                            format(field.value, "PPP")
                          ) : (
                            <span>Pick a date</span>
                          )}
                          <CalendarIcon className="ml-auto h-4 w-4 opacity-50" />
                        </Button>
                      </FormControl>
                    </PopoverTrigger>
                    <PopoverContent className="w-auto p-0" align="start">
                      <Calendar
                        mode="single"
                        selected={field.value}
                        onSelect={field.onChange}
                        disabled={(date) =>
                          watchedStartDate ? date < watchedStartDate : date < new Date()
                        }
                        initialFocus
                      />
                    </PopoverContent>
                  </Popover>
                  <FormDescription>
                    When the campaign should end
                  </FormDescription>
                  <FormMessage />
                </FormItem>
              )}
            />
          </div>

          {/* Campaign duration display */}
          {campaignDuration > 0 && (
            <div className="p-4 bg-muted/50 rounded-lg">
              <p className="text-sm">
                <span className="font-medium">Campaign Duration:</span> {campaignDuration} day{campaignDuration !== 1 ? 's' : ''}
              </p>
              {campaignDuration < 7 && (
                <p className="text-sm text-amber-600 mt-1">
                  ⚠️ Short campaigns may have limited effectiveness
                </p>
              )}
              {campaignDuration > 90 && (
                <p className="text-sm text-blue-600 mt-1">
                  ℹ️ Consider breaking long campaigns into phases for better management
                </p>
              )}
            </div>
          )}

          <FormField
            control={form.control}
            name="budgetSchedule.schedule.timezone"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Timezone</FormLabel>
                <Select onValueChange={field.onChange} value={field.value}>
                  <FormControl>
                    <SelectTrigger>
                      <SelectValue placeholder="Select timezone" />
                    </SelectTrigger>
                  </FormControl>
                  <SelectContent>
                    {timezoneOptions.map((timezone) => (
                      <SelectItem key={timezone} value={timezone}>
                        {timezone.replace(/_/g, ' ')}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <FormDescription>
                  The timezone for campaign scheduling and reporting
                </FormDescription>
                <FormMessage />
              </FormItem>
            )}
          />
        </CardContent>
      </Card>

      {/* Budget recommendations */}
      {form.watch("budgetSchedule.budget.total") > 0 && selectedChannels.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Budget Recommendations</CardTitle>
            <CardDescription>
              Suggested budget allocation based on your selected channels
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {selectedChannels.map((channel, index) => {
                const percentage = Math.floor(100 / selectedChannels.length)
                const amount = (form.watch("budgetSchedule.budget.total") * percentage / 100).toFixed(2)
                return (
                  <div key={channel} className="flex justify-between items-center text-sm">
                    <span className="capitalize">{channel.replace('-', ' ')}</span>
                    <span className="font-medium">
                      {currencySymbol}{amount} ({percentage}%)
                    </span>
                  </div>
                )
              })}
            </div>
            <p className="text-xs text-muted-foreground mt-4">
              This is a suggested equal distribution. You can adjust allocations after campaign creation.
            </p>
          </CardContent>
        </Card>
      )}
    </div>
  )
}