'use client'

import { useFormContext } from 'react-hook-form'

import { Briefcase,Calendar, MapPin, Users } from 'lucide-react'

import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Checkbox } from '@/components/ui/checkbox'
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


const ageRanges = [
  { value: '18-24', label: '18-24 years' },
  { value: '25-34', label: '25-34 years' },
  { value: '35-44', label: '35-44 years' },
  { value: '45-54', label: '45-54 years' },
  { value: '55-64', label: '55-64 years' },
  { value: '65+', label: '65+ years' },
]

const genderOptions = [
  { value: 'all', label: 'All genders' },
  { value: 'male', label: 'Male' },
  { value: 'female', label: 'Female' },
  { value: 'non-binary', label: 'Non-binary' },
]

const locationOptions = [
  { value: 'us', label: 'United States' },
  { value: 'ca', label: 'Canada' },
  { value: 'uk', label: 'United Kingdom' },
  { value: 'au', label: 'Australia' },
  { value: 'de', label: 'Germany' },
  { value: 'fr', label: 'France' },
  { value: 'jp', label: 'Japan' },
  { value: 'global', label: 'Global' },
]

const segmentOptions = [
  { value: 'new-customers', label: 'New Customers', description: 'First-time buyers or recent signups' },
  { value: 'returning-customers', label: 'Returning Customers', description: 'Previous purchasers' },
  { value: 'high-value', label: 'High-Value Customers', description: 'Top spending customers' },
  { value: 'inactive', label: 'Inactive Users', description: 'Haven\'t engaged recently' },
  { value: 'prospects', label: 'Prospects', description: 'Leads not yet converted' },
  { value: 'trial-users', label: 'Trial Users', description: 'Currently in trial period' },
]

export function TargetAudienceStep() {
  const { control, watch } = useFormContext()
  const selectedSegments = watch('targetAudience.segments') || []

  return (
    <div data-testid="target-audience-step" className="space-y-6">
      <div>
        <h3 className="text-lg font-semibold">Target Audience</h3>
        <p className="text-muted-foreground text-sm">
          Define who you want to reach with this campaign. This step is optional - you can configure targeting later.
        </p>
      </div>

      <div className="grid gap-6">
        {/* Customer Segments */}
        <Card>
          <CardHeader>
            <CardTitle className="text-base flex items-center gap-2">
              <Users className="h-4 w-4" />
              Customer Segments
            </CardTitle>
            <CardDescription>
              Select the customer segments you want to target
            </CardDescription>
          </CardHeader>
          <CardContent>
            <FormField
              control={control}
              name="targetAudience.segments"
              render={() => (
                <FormItem>
                  <div className="grid gap-3 md:grid-cols-2">
                    {segmentOptions.map((segment) => (
                      <FormField
                        key={segment.value}
                        control={control}
                        name="targetAudience.segments"
                        render={({ field }) => {
                          // Ensure field.value is always an array to prevent controlled/uncontrolled warnings
                          const currentValue = field.value || []
                          const isSelected = currentValue.includes(segment.value)
                          return (
                            <FormItem>
                              <FormControl>
                                <div
                                  className={`relative rounded-lg border p-3 cursor-pointer transition-all hover:border-primary/50 ${
                                    isSelected ? 'border-primary bg-primary/5' : 'border-border'
                                  }`}
                                  onClick={() => {
                                    const newValue = isSelected
                                      ? currentValue.filter((v: string) => v !== segment.value)
                                      : [...currentValue, segment.value]
                                    field.onChange(newValue)
                                  }}
                                  role="button"
                                  tabIndex={0}
                                  onKeyDown={(e) => {
                                    if (e.key === 'Enter' || e.key === ' ') {
                                      e.preventDefault()
                                      const newValue = isSelected
                                        ? currentValue.filter((v: string) => v !== segment.value)
                                        : [...currentValue, segment.value]
                                      field.onChange(newValue)
                                    }
                                  }}
                                >
                                  <div className="flex items-start gap-3">
                                    <Checkbox
                                      checked={isSelected}
                                      className="mt-0.5 pointer-events-none"
                                      onChange={() => {}} 
                                      aria-hidden="true"
                                    />
                                    <div className="flex-1 min-w-0">
                                      <div className="font-medium text-sm">{segment.label}</div>
                                      <div className="text-muted-foreground text-xs mt-1">
                                        {segment.description}
                                      </div>
                                    </div>
                                  </div>
                                </div>
                              </FormControl>
                            </FormItem>
                          )
                        }}
                      />
                    ))}
                  </div>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            {selectedSegments.length > 0 && (
              <div className="mt-4 p-3 rounded-lg bg-muted/50">
                <div className="text-sm font-medium mb-2">Selected Segments:</div>
                <div className="flex flex-wrap gap-2">
                  {selectedSegments.map((segmentValue: string) => {
                    const segment = segmentOptions.find(s => s.value === segmentValue)
                    return (
                      <Badge key={segmentValue} variant="secondary">
                        {segment?.label}
                      </Badge>
                    )
                  })}
                </div>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Demographics */}
        <Card>
          <CardHeader>
            <CardTitle className="text-base flex items-center gap-2">
              <Calendar className="h-4 w-4" />
              Demographics
            </CardTitle>
            <CardDescription>
              Optional demographic targeting
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid gap-4 md:grid-cols-2">
              <FormField
                control={control}
                name="targetAudience.demographics.gender"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Gender</FormLabel>
                    <Select onValueChange={(value) => field.onChange([value])} defaultValue="">
                      <FormControl>
                        <SelectTrigger>
                          <SelectValue placeholder="Select gender targeting" />
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

              <FormField
                control={control}
                name="targetAudience.demographics.locations"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Primary Location</FormLabel>
                    <Select onValueChange={(value) => field.onChange([value])} defaultValue="">
                      <FormControl>
                        <SelectTrigger>
                          <SelectValue placeholder="Select location" />
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        {locationOptions.map((option) => (
                          <SelectItem key={option.value} value={option.value}>
                            <div className="flex items-center gap-2">
                              <MapPin className="h-3 w-3" />
                              {option.label}
                            </div>
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>
          </CardContent>
        </Card>

        {/* Estimated Audience Size */}
        <Card>
          <CardHeader>
            <CardTitle className="text-base flex items-center gap-2">
              <Briefcase className="h-4 w-4" />
              Audience Size
            </CardTitle>
            <CardDescription>
              Estimated number of people in your target audience
            </CardDescription>
          </CardHeader>
          <CardContent>
            <FormField
              control={control}
              name="targetAudience.estimatedSize"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Estimated Audience Size</FormLabel>
                  <FormControl>
                    <Input
                      type="number"
                      placeholder="e.g., 10000"
                      {...field}
                      onChange={(e) => field.onChange(parseInt(e.target.value) || 0)}
                    />
                  </FormControl>
                  <FormDescription>
                    Approximate number of people you expect to reach with this campaign.
                  </FormDescription>
                  <FormMessage />
                </FormItem>
              )}
            />
          </CardContent>
        </Card>
      </div>

      <div className="rounded-lg bg-muted/50 p-4">
        <div className="flex items-start gap-3">
          <div className="mt-0.5">
            <div className="h-2 w-2 rounded-full bg-blue-500" />
          </div>
          <div className="text-sm">
            <p className="font-medium">Next up: Goals & KPIs</p>
            <p className="text-muted-foreground">
              Set your success metrics and budget for this campaign.
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}