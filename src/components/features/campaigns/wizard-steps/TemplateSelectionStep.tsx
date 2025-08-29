'use client'

import { useFormContext } from 'react-hook-form'

import { CheckCircle2, Mail,RefreshCw, Rocket, Target, TrendingUp, Users } from 'lucide-react'

import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import {
  FormControl,
  FormField,
  FormItem,
  FormMessage,
} from '@/components/ui/form'
import { cn } from '@/lib/utils'


interface JourneyTemplate {
  id: string
  name: string
  description: string
  icon: React.ComponentType<{ className?: string }>
  category: string
  estimatedDuration: string
  stages: string[]
  metrics: string[]
  recommended: boolean
  difficulty: 'Beginner' | 'Intermediate' | 'Advanced'
}

const journeyTemplates: JourneyTemplate[] = [
  {
    id: 'product-launch',
    name: 'Product Launch',
    description: 'Comprehensive product launch journey with pre-launch buzz, launch event, and post-launch follow-up.',
    icon: Rocket,
    category: 'Product Marketing',
    estimatedDuration: '8-12 weeks',
    stages: ['Pre-launch', 'Launch Week', 'Post-launch', 'Growth'],
    metrics: ['Pre-orders', 'Launch conversions', 'Product adoption', 'Customer satisfaction'],
    recommended: true,
    difficulty: 'Intermediate',
  },
  {
    id: 'lead-gen-funnel',
    name: 'Lead Generation Funnel',
    description: 'Multi-touch lead nurturing campaign designed to convert prospects into qualified leads.',
    icon: Target,
    category: 'Lead Generation',
    estimatedDuration: '4-8 weeks',
    stages: ['Awareness', 'Interest', 'Consideration', 'Conversion'],
    metrics: ['Lead quality score', 'Conversion rate', 'Cost per lead', 'Pipeline value'],
    recommended: true,
    difficulty: 'Beginner',
  },
  {
    id: 're-engagement',
    name: 'Re-engagement Campaign',
    description: 'Win back inactive customers with personalized messaging and compelling offers.',
    icon: RefreshCw,
    category: 'Customer Retention',
    estimatedDuration: '3-6 weeks',
    stages: ['Segmentation', 'Outreach', 'Offer', 'Re-activation'],
    metrics: ['Reactivation rate', 'Engagement lift', 'Revenue recovery', 'Churn reduction'],
    recommended: false,
    difficulty: 'Advanced',
  },
  {
    id: 'customer-onboarding',
    name: 'Customer Onboarding',
    description: 'Guide new customers through product adoption with educational content and support.',
    icon: Users,
    category: 'Customer Success',
    estimatedDuration: '2-4 weeks',
    stages: ['Welcome', 'Setup', 'First Value', 'Adoption'],
    metrics: ['Time to first value', 'Feature adoption', 'Support tickets', 'NPS score'],
    recommended: false,
    difficulty: 'Beginner',
  },
  {
    id: 'upsell-cross-sell',
    name: 'Upsell & Cross-sell',
    description: 'Identify expansion opportunities and guide existing customers to higher-value products.',
    icon: TrendingUp,
    category: 'Revenue Growth',
    estimatedDuration: '6-10 weeks',
    stages: ['Analysis', 'Targeting', 'Proposition', 'Conversion'],
    metrics: ['Upsell rate', 'Average deal size', 'Customer lifetime value', 'Revenue growth'],
    recommended: false,
    difficulty: 'Intermediate',
  },
  {
    id: 'email-nurture',
    name: 'Email Nurture Series',
    description: 'Educational email sequence that builds trust and guides prospects toward purchase.',
    icon: Mail,
    category: 'Email Marketing',
    estimatedDuration: '3-5 weeks',
    stages: ['Education', 'Trust Building', 'Social Proof', 'Call to Action'],
    metrics: ['Open rate', 'Click rate', 'Unsubscribe rate', 'Email conversions'],
    recommended: false,
    difficulty: 'Beginner',
  },
]

export function TemplateSelectionStep() {
  const { control, watch, setValue } = useFormContext()
  const selectedTemplateId = watch('templateId')

  return (
    <div data-testid="template-selection-step" className="space-y-6">
      <div>
        <h3 className="text-lg font-semibold">Choose Journey Template</h3>
        <p className="text-muted-foreground text-sm">
          Select a pre-built template that aligns with your campaign goals. You can customize it in the next steps.
        </p>
      </div>

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {journeyTemplates.map((template) => {
          const isSelected = selectedTemplateId === template.id
          const Icon = template.icon

          return (
            <Card
              key={template.id}
              className={cn(
                'cursor-pointer transition-all hover:shadow-md',
                isSelected && 'ring-2 ring-primary ring-offset-2'
              )}
              onClick={() => {
                console.log('Direct template click:', template.id)
                setValue('templateId', template.id)
                console.log('Template value set to:', template.id)
              }}
            >
              <CardHeader className="pb-3">
                <div className="flex items-start justify-between">
                  <div className="flex items-center gap-3">
                    <div className="rounded-lg bg-primary/10 p-2">
                      <Icon className="h-5 w-5 text-primary" />
                    </div>
                    <div>
                      <CardTitle className="text-base">{template.name}</CardTitle>
                      <div className="flex items-center gap-2 mt-1">
                        {template.recommended && (
                          <Badge variant="default" className="text-xs">
                            Recommended
                          </Badge>
                        )}
                        <Badge variant="outline" className="text-xs">
                          {template.difficulty}
                        </Badge>
                      </div>
                    </div>
                  </div>
                  {isSelected && (
                    <CheckCircle2 className="h-5 w-5 text-primary" />
                  )}
                </div>
              </CardHeader>
              
              <CardContent className="space-y-3">
                <CardDescription className="text-sm leading-relaxed">
                  {template.description}
                </CardDescription>
                
                <div className="space-y-2 text-xs">
                  <div>
                    <span className="font-medium text-foreground">Duration:</span>
                    <span className="text-muted-foreground ml-1">{template.estimatedDuration}</span>
                  </div>
                  
                  <div>
                    <span className="font-medium text-foreground">Stages:</span>
                    <div className="mt-1 flex flex-wrap gap-1">
                      {template.stages.slice(0, 3).map((stage) => (
                        <Badge key={stage} variant="secondary" className="text-xs">
                          {stage}
                        </Badge>
                      ))}
                      {template.stages.length > 3 && (
                        <Badge variant="secondary" className="text-xs">
                          +{template.stages.length - 3} more
                        </Badge>
                      )}
                    </div>
                  </div>
                  
                  <div>
                    <span className="font-medium text-foreground">Key Metrics:</span>
                    <div className="mt-1">
                      <span className="text-muted-foreground">
                        {template.metrics.slice(0, 2).join(', ')}
                        {template.metrics.length > 2 && '...'}
                      </span>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          )
        })}
      </div>

      {selectedTemplateId && (
        <div className="rounded-lg bg-muted/50 p-4">
          <div className="flex items-start gap-3">
            <div className="mt-0.5">
              <div className="h-2 w-2 rounded-full bg-green-500" />
            </div>
            <div className="text-sm">
              <p className="font-medium">Template Selected</p>
              <p className="text-muted-foreground">
                {journeyTemplates.find(t => t.id === selectedTemplateId)?.name} - 
                You can customize this template's stages and messaging in the journey builder.
              </p>
            </div>
          </div>
        </div>
      )}

      <div className="rounded-lg bg-muted/50 p-4">
        <div className="flex items-start gap-3">
          <div className="mt-0.5">
            <div className="h-2 w-2 rounded-full bg-blue-500" />
          </div>
          <div className="text-sm">
            <p className="font-medium">Next up: Target Audience</p>
            <p className="text-muted-foreground">
              Define who you want to reach with this campaign (optional step).
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}