"use client"

import * as React from "react"
import { UseFormReturn } from "react-hook-form"
import { FormField, FormItem, FormLabel, FormControl, FormDescription, FormMessage } from "@/components/ui/form"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Checkbox } from "@/components/ui/checkbox"
import { 
  type CampaignWizardData,
  campaignTemplates,
  type CampaignTemplate
} from "../campaign-wizard-schemas"

interface CampaignBasicsStepProps {
  form: UseFormReturn<CampaignWizardData>
  onTemplateChange?: (template: CampaignTemplate) => void
}

const objectiveLabels = {
  'brand-awareness': 'Brand Awareness',
  'lead-generation': 'Lead Generation',
  'sales-conversion': 'Sales Conversion',
  'customer-retention': 'Customer Retention',
  'engagement': 'Engagement',
  'traffic-increase': 'Traffic Increase',
} as const

export function CampaignBasicsStep({ form, onTemplateChange }: CampaignBasicsStepProps) {
  const [selectedTemplate, setSelectedTemplate] = React.useState<CampaignTemplate | undefined>(
    form.getValues("basics.template")
  )

  const handleTemplateSelect = (templateKey: CampaignTemplate) => {
    setSelectedTemplate(templateKey)
    form.setValue("basics.template", templateKey)
    onTemplateChange?.(templateKey)
  }

  const selectedObjectives = form.watch("basics.objectives") || []

  const handleObjectiveChange = (objective: string, checked: boolean) => {
    const current = selectedObjectives
    if (checked) {
      form.setValue("basics.objectives", [...current, objective] as any)
    } else {
      form.setValue("basics.objectives", current.filter(obj => obj !== objective) as any)
    }
  }

  return (
    <div className="space-y-8">
      {/* Campaign Name and Description */}
      <div className="space-y-6">
        <FormField
          control={form.control}
          name="basics.name"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Campaign Name</FormLabel>
              <FormControl>
                <Input
                  placeholder="Enter a descriptive campaign name"
                  {...field}
                />
              </FormControl>
              <FormDescription>
                Choose a clear, memorable name for your campaign
              </FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="basics.description"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Campaign Description</FormLabel>
              <FormControl>
                <Textarea
                  placeholder="Describe the purpose and goals of your campaign..."
                  rows={4}
                  {...field}
                />
              </FormControl>
              <FormDescription>
                Provide a detailed description of your campaign goals and strategy
              </FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />
      </div>

      {/* Campaign Template Selection */}
      <div className="space-y-4">
        <div>
          <FormLabel>Campaign Template (Optional)</FormLabel>
          <p className="text-sm text-muted-foreground mt-1">
            Choose a template to pre-fill common settings, or start with a blank campaign
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {Object.entries(campaignTemplates).map(([key, template]) => (
            <Card
              key={key}
              className={`cursor-pointer transition-all hover:shadow-md ${
                selectedTemplate === key
                  ? "ring-2 ring-primary border-primary"
                  : "border-muted"
              }`}
              onClick={() => handleTemplateSelect(key as CampaignTemplate)}
            >
              <CardContent className="p-4">
                <div className="flex items-start space-x-3">
                  <div className="text-2xl flex-shrink-0">
                    {template.icon}
                  </div>
                  <div className="flex-1 min-w-0">
                    <h4 className="font-medium text-sm mb-1">
                      {template.name}
                    </h4>
                    <p className="text-xs text-muted-foreground">
                      {template.description}
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>

        {selectedTemplate && selectedTemplate !== 'blank' && (
          <div className="mt-4 p-4 bg-muted/50 rounded-lg">
            <h4 className="font-medium text-sm mb-2">Template Presets:</h4>
            <div className="space-y-2 text-xs text-muted-foreground">
              {campaignTemplates[selectedTemplate].presets.objectives && (
                <div>
                  <span className="font-medium">Objectives:</span> {
                    campaignTemplates[selectedTemplate].presets.objectives?.join(", ")
                  }
                </div>
              )}
              {campaignTemplates[selectedTemplate].presets.channels && (
                <div>
                  <span className="font-medium">Channels:</span> {
                    campaignTemplates[selectedTemplate].presets.channels?.join(", ")
                  }
                </div>
              )}
              {campaignTemplates[selectedTemplate].presets.contentTypes && (
                <div>
                  <span className="font-medium">Content Types:</span> {
                    campaignTemplates[selectedTemplate].presets.contentTypes?.join(", ")
                  }
                </div>
              )}
            </div>
          </div>
        )}
      </div>

      {/* Campaign Objectives */}
      <div className="space-y-4">
        <FormField
          control={form.control}
          name="basics.objectives"
          render={() => (
            <FormItem>
              <FormLabel>Campaign Objectives</FormLabel>
              <FormDescription>
                Select one or more primary objectives for this campaign
              </FormDescription>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
                {Object.entries(objectiveLabels).map(([value, label]) => (
                  <div key={value} className="flex items-center space-x-2">
                    <Checkbox
                      id={`objective-${value}`}
                      checked={selectedObjectives.includes(value)}
                      onCheckedChange={(checked) => 
                        handleObjectiveChange(value, checked as boolean)
                      }
                    />
                    <label
                      htmlFor={`objective-${value}`}
                      className="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70 cursor-pointer"
                    >
                      {label}
                    </label>
                  </div>
                ))}
              </div>
              <FormMessage />
            </FormItem>
          )}
        />

        {/* Show selected objectives */}
        {selectedObjectives.length > 0 && (
          <div className="mt-4">
            <p className="text-sm text-muted-foreground mb-2">Selected objectives:</p>
            <div className="flex flex-wrap gap-2">
              {selectedObjectives.map((objective) => (
                <Badge key={objective} variant="secondary">
                  {objectiveLabels[objective as keyof typeof objectiveLabels]}
                </Badge>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  )
}