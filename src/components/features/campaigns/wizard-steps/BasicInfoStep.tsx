'use client'

import { useFormContext } from 'react-hook-form'

import { DatePicker } from '@/components/ui/date-picker'
import {
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from '@/components/ui/form'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'


export function BasicInfoStep() {
  const { control } = useFormContext()

  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-lg font-semibold">Campaign Basic Information</h3>
        <p className="text-muted-foreground text-sm">
          Start by giving your campaign a name and describing what you want to achieve.
        </p>
      </div>

      <div className="grid gap-6">
        {/* Campaign Name */}
        <FormField
          control={control}
          name="name"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Campaign Name</FormLabel>
              <FormControl>
                <Input
                  placeholder="e.g., Summer Product Launch 2024"
                  {...field}
                />
              </FormControl>
              <FormDescription>
                Choose a descriptive name that helps you identify this campaign.
              </FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />

        {/* Campaign Description */}
        <FormField
          control={control}
          name="description"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Description</FormLabel>
              <FormControl>
                <Textarea
                  placeholder="Describe the purpose and goals of this campaign..."
                  className="min-h-[100px]"
                  {...field}
                />
              </FormControl>
              <FormDescription>
                Provide details about what this campaign aims to accomplish.
              </FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />

        {/* Campaign Timeline */}
        <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
          <FormField
            control={control}
            name="startDate"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Start Date</FormLabel>
                <FormControl>
                  <DatePicker
                    value={field.value}
                    onChange={field.onChange}
                    placeholder="Select campaign start date"
                  />
                </FormControl>
                <FormDescription>
                  When should this campaign begin?
                </FormDescription>
                <FormMessage />
              </FormItem>
            )}
          />

          <FormField
            control={control}
            name="endDate"
            render={({ field }) => (
              <FormItem>
                <FormLabel>End Date</FormLabel>
                <FormControl>
                  <DatePicker
                    value={field.value}
                    onChange={field.onChange}
                    placeholder="Select campaign end date"
                  />
                </FormControl>
                <FormDescription>
                  When should this campaign end?
                </FormDescription>
                <FormMessage />
              </FormItem>
            )}
          />
        </div>
      </div>

      <div className="rounded-lg bg-muted/50 p-4">
        <div className="flex items-start gap-3">
          <div className="mt-0.5">
            <div className="h-2 w-2 rounded-full bg-blue-500" />
          </div>
          <div className="text-sm">
            <p className="font-medium">Next up: Journey Template</p>
            <p className="text-muted-foreground">
              Choose from pre-built journey templates that match your campaign goals.
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}