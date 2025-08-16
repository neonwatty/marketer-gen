'use client'

import { useFormContext } from 'react-hook-form'
import { Target, DollarSign, TrendingUp, Users, ShoppingCart, Mail, Eye } from 'lucide-react'

import {
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from '@/components/ui/form'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { cn } from '@/lib/utils'
import { type CampaignFormData } from '../CampaignWizard'

const primaryGoalOptions = [
  {
    value: 'brand-awareness',
    label: 'Brand Awareness',
    description: 'Increase brand recognition and reach',
    icon: Eye,
    metrics: ['Impressions', 'Reach', 'Brand recall'],
  },
  {
    value: 'lead-generation',
    label: 'Lead Generation',
    description: 'Generate qualified leads for sales team',
    icon: Users,
    metrics: ['Lead quality', 'Cost per lead', 'Conversion rate'],
  },
  {
    value: 'sales-conversion',
    label: 'Sales & Conversions',
    description: 'Drive direct sales and revenue',
    icon: ShoppingCart,
    metrics: ['Revenue', 'ROAS', 'Conversion rate'],
  },
  {
    value: 'engagement',
    label: 'Engagement',
    description: 'Increase customer engagement and interaction',
    icon: TrendingUp,
    metrics: ['Engagement rate', 'Time on site', 'Social shares'],
  },
  {
    value: 'email-growth',
    label: 'Email List Growth',
    description: 'Grow email subscriber base',
    icon: Mail,
    metrics: ['Subscriber growth', 'List quality', 'Open rates'],
  },
  {
    value: 'retention',
    label: 'Customer Retention',
    description: 'Retain existing customers and reduce churn',
    icon: Target,
    metrics: ['Retention rate', 'Churn reduction', 'Customer lifetime value'],
  },
]

export function GoalsKPIsStep() {
  const { control, watch } = useFormContext()
  const selectedGoal = watch('goals.primary')
  const selectedGoalOption = primaryGoalOptions.find(goal => goal.value === selectedGoal)

  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-lg font-semibold">Goals & KPIs</h3>
        <p className="text-muted-foreground text-sm">
          Define what success looks like for this campaign and set your budget.
        </p>
      </div>

      <div className="grid gap-6">
        {/* Primary Goal Selection */}
        <Card>
          <CardHeader>
            <CardTitle className="text-base flex items-center gap-2">
              <Target className="h-4 w-4" />
              Primary Goal
            </CardTitle>
            <CardDescription>
              What is the main objective of this campaign?
            </CardDescription>
          </CardHeader>
          <CardContent>
            <FormField
              control={control}
              name="goals.primary"
              render={({ field }) => (
                <FormItem>
                  <FormControl>
                    <div className="grid gap-3 md:grid-cols-2 lg:grid-cols-3">
                      {primaryGoalOptions.map((goal) => {
                        const isSelected = field.value === goal.value
                        const Icon = goal.icon

                        return (
                          <div
                            key={goal.value}
                            className={cn(
                              'relative rounded-lg border p-4 cursor-pointer transition-all hover:border-primary/50',
                              isSelected ? 'border-primary bg-primary/5' : 'border-border'
                            )}
                            onClick={() => field.onChange(goal.value)}
                          >
                            <div className="flex items-start gap-3">
                              <div className="rounded-lg bg-primary/10 p-2 mt-1">
                                <Icon className="h-4 w-4 text-primary" />
                              </div>
                              <div className="flex-1 min-w-0">
                                <div className="font-medium text-sm">{goal.label}</div>
                                <div className="text-muted-foreground text-xs mt-1 leading-relaxed">
                                  {goal.description}
                                </div>
                                <div className="flex flex-wrap gap-1 mt-2">
                                  {goal.metrics.slice(0, 2).map((metric) => (
                                    <Badge key={metric} variant="outline" className="text-xs">
                                      {metric}
                                    </Badge>
                                  ))}
                                </div>
                              </div>
                            </div>
                          </div>
                        )
                      })}
                    </div>
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            {selectedGoalOption && (
              <div className="mt-4 p-3 rounded-lg bg-muted/50">
                <div className="text-sm font-medium mb-2">Key Metrics for {selectedGoalOption.label}:</div>
                <div className="flex flex-wrap gap-2">
                  {selectedGoalOption.metrics.map((metric) => (
                    <Badge key={metric} variant="secondary">
                      {metric}
                    </Badge>
                  ))}
                </div>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Budget & Targets */}
        <Card>
          <CardHeader>
            <CardTitle className="text-base flex items-center gap-2">
              <DollarSign className="h-4 w-4" />
              Budget & Targets
            </CardTitle>
            <CardDescription>
              Set your campaign budget and success targets
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid gap-4 md:grid-cols-2">
              <FormField
                control={control}
                name="goals.budget"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Total Budget ($)</FormLabel>
                    <FormControl>
                      <Input
                        type="number"
                        placeholder="e.g., 5000"
                        {...field}
                        onChange={(e) => field.onChange(parseFloat(e.target.value) || 0)}
                      />
                    </FormControl>
                    <FormDescription>
                      Total budget allocated for this campaign
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={control}
                name="goals.targetConversions"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Target Conversions</FormLabel>
                    <FormControl>
                      <Input
                        type="number"
                        placeholder="e.g., 100"
                        {...field}
                        onChange={(e) => field.onChange(parseInt(e.target.value) || 1)}
                      />
                    </FormControl>
                    <FormDescription>
                      Number of conversions you want to achieve
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>

            <FormField
              control={control}
              name="goals.targetEngagementRate"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Target Engagement Rate (%)</FormLabel>
                  <FormControl>
                    <Input
                      type="number"
                      min="0"
                      max="100"
                      step="0.1"
                      placeholder="e.g., 3.5"
                      {...field}
                      onChange={(e) => field.onChange(parseFloat(e.target.value) || 0)}
                    />
                  </FormControl>
                  <FormDescription>
                    Expected engagement rate as a percentage (clicks, likes, shares, etc.)
                  </FormDescription>
                  <FormMessage />
                </FormItem>
              )}
            />
          </CardContent>
        </Card>

        {/* Success Metrics Preview */}
        {selectedGoal && (
          <Card>
            <CardHeader>
              <CardTitle className="text-base flex items-center gap-2">
                <TrendingUp className="h-4 w-4" />
                Success Metrics Overview
              </CardTitle>
              <CardDescription>
                Based on your goal and budget, here's what success might look like
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="grid gap-4 md:grid-cols-3">
                <div className="text-center p-3 rounded-lg bg-muted/50">
                  <div className="text-2xl font-bold text-primary">
                    ${watch('goals.budget') || 0}
                  </div>
                  <div className="text-sm text-muted-foreground">Total Budget</div>
                </div>
                
                <div className="text-center p-3 rounded-lg bg-muted/50">
                  <div className="text-2xl font-bold text-primary">
                    {watch('goals.targetConversions') || 0}
                  </div>
                  <div className="text-sm text-muted-foreground">Target Conversions</div>
                </div>
                
                <div className="text-center p-3 rounded-lg bg-muted/50">
                  <div className="text-2xl font-bold text-primary">
                    ${watch('goals.budget') && watch('goals.targetConversions') 
                      ? Math.round((watch('goals.budget') || 0) / (watch('goals.targetConversions') || 1) * 100) / 100
                      : 0
                    }
                  </div>
                  <div className="text-sm text-muted-foreground">Cost per Conversion</div>
                </div>
              </div>
            </CardContent>
          </Card>
        )}
      </div>

      <div className="rounded-lg bg-muted/50 p-4">
        <div className="flex items-start gap-3">
          <div className="mt-0.5">
            <div className="h-2 w-2 rounded-full bg-blue-500" />
          </div>
          <div className="text-sm">
            <p className="font-medium">Next up: Review</p>
            <p className="text-muted-foreground">
              Review your campaign settings and create your campaign.
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}