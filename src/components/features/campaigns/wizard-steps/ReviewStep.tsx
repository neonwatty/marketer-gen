'use client'

import { useFormContext } from 'react-hook-form'

import { 
  Calendar, 
  CheckCircle2, 
  DollarSign,
  FileText, 
  Save,
  Target, 
  Users} from 'lucide-react'

import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'


interface ReviewStepProps {
  onSaveDraft?: () => Promise<void> | void
}

const journeyTemplates = [
  { id: 'product-launch', name: 'Product Launch', category: 'Product Marketing' },
  { id: 'lead-gen-funnel', name: 'Lead Generation Funnel', category: 'Lead Generation' },
  { id: 're-engagement', name: 'Re-engagement Campaign', category: 'Customer Retention' },
  { id: 'customer-onboarding', name: 'Customer Onboarding', category: 'Customer Success' },
  { id: 'upsell-cross-sell', name: 'Upsell & Cross-sell', category: 'Revenue Growth' },
  { id: 'email-nurture', name: 'Email Nurture Series', category: 'Email Marketing' },
]

const primaryGoals = [
  { value: 'brand-awareness', label: 'Brand Awareness' },
  { value: 'lead-generation', label: 'Lead Generation' },
  { value: 'sales-conversion', label: 'Sales & Conversions' },
  { value: 'engagement', label: 'Engagement' },
  { value: 'email-growth', label: 'Email List Growth' },
  { value: 'retention', label: 'Customer Retention' },
]

export function ReviewStep({ onSaveDraft }: ReviewStepProps) {
  const { watch } = useFormContext()
  const formData = watch()

  const selectedTemplate = journeyTemplates.find(t => t.id === formData.templateId)
  const selectedGoal = primaryGoals.find(g => g.value === formData.goals?.primary)

  const formatDate = (dateString: string) => {
    if (!dateString) return 'Not set'
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    })
  }

  const calculateDuration = () => {
    if (!formData.startDate || !formData.endDate) return 'Not calculated'
    
    const start = new Date(formData.startDate)
    const end = new Date(formData.endDate)
    const diffTime = Math.abs(end.getTime() - start.getTime())
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))
    
    if (diffDays === 1) return '1 day'
    if (diffDays < 7) return `${diffDays} days`
    if (diffDays < 30) return `${Math.ceil(diffDays / 7)} weeks`
    return `${Math.ceil(diffDays / 30)} months`
  }

  return (
    <div data-testid="review-step" className="space-y-6">
      <div>
        <h3 className="text-lg font-semibold">Review Campaign</h3>
        <p className="text-muted-foreground text-sm">
          Review your campaign settings before creating. You can edit any section or save as draft.
        </p>
      </div>

      <div className="grid gap-6">
        {/* Campaign Overview */}
        <Card>
          <CardHeader>
            <CardTitle className="text-base flex items-center gap-2">
              <FileText className="h-4 w-4" />
              Campaign Overview
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid gap-4 md:grid-cols-2">
              <div>
                <div className="text-sm font-medium text-muted-foreground">Campaign Name</div>
                <div className="text-lg font-semibold">{formData.name || 'Untitled Campaign'}</div>
              </div>
              
              <div>
                <div className="text-sm font-medium text-muted-foreground">Duration</div>
                <div className="text-lg font-semibold">{calculateDuration()}</div>
              </div>
            </div>
            
            <div>
              <div className="text-sm font-medium text-muted-foreground mb-2">Description</div>
              <p className="text-sm leading-relaxed">
                {formData.description || 'No description provided'}
              </p>
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              <div className="flex items-center gap-2 text-sm">
                <Calendar className="h-4 w-4 text-muted-foreground" />
                <span>Starts: {formatDate(formData.startDate)}</span>
              </div>
              
              <div className="flex items-center gap-2 text-sm">
                <Calendar className="h-4 w-4 text-muted-foreground" />
                <span>Ends: {formatDate(formData.endDate)}</span>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Journey Template */}
        <Card>
          <CardHeader>
            <CardTitle className="text-base flex items-center gap-2">
              <Target className="h-4 w-4" />
              Journey Template
            </CardTitle>
          </CardHeader>
          <CardContent>
            {selectedTemplate ? (
              <div className="flex items-center justify-between">
                <div>
                  <div className="font-semibold">{selectedTemplate.name}</div>
                  <div className="text-sm text-muted-foreground">{selectedTemplate.category}</div>
                </div>
                <Badge variant="secondary">Selected</Badge>
              </div>
            ) : (
              <div className="text-muted-foreground">No template selected</div>
            )}
          </CardContent>
        </Card>

        {/* Target Audience */}
        <Card>
          <CardHeader>
            <CardTitle className="text-base flex items-center gap-2">
              <Users className="h-4 w-4" />
              Target Audience
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {formData.targetAudience?.segments && formData.targetAudience.segments.length > 0 ? (
              <div>
                <div className="text-sm font-medium text-muted-foreground mb-2">Customer Segments</div>
                <div className="flex flex-wrap gap-2">
                  {formData.targetAudience.segments.map((segment: string) => (
                    <Badge key={segment} variant="outline">
                      {segment.replace('-', ' ').replace(/\b\w/g, (l: string) => l.toUpperCase())}
                    </Badge>
                  ))}
                </div>
              </div>
            ) : null}

            {formData.targetAudience?.estimatedSize && (
              <div className="flex items-center gap-2 text-sm">
                <Users className="h-4 w-4 text-muted-foreground" />
                <span>Estimated reach: {formData.targetAudience.estimatedSize.toLocaleString()} people</span>
              </div>
            )}

            {(!formData.targetAudience?.segments || formData.targetAudience.segments.length === 0) && 
             !formData.targetAudience?.estimatedSize && (
              <div className="text-muted-foreground text-sm">
                No specific audience targeting configured - will use default targeting
              </div>
            )}
          </CardContent>
        </Card>

        {/* Goals & Budget */}
        <Card>
          <CardHeader>
            <CardTitle className="text-base flex items-center gap-2">
              <DollarSign className="h-4 w-4" />
              Goals & Budget
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
              <div className="text-center p-3 rounded-lg bg-muted/50">
                <div className="text-lg font-bold">
                  {selectedGoal?.label || 'Not set'}
                </div>
                <div className="text-xs text-muted-foreground">Primary Goal</div>
              </div>
              
              <div className="text-center p-3 rounded-lg bg-muted/50">
                <div className="text-lg font-bold">
                  ${formData.goals?.budget?.toLocaleString() || 0}
                </div>
                <div className="text-xs text-muted-foreground">Total Budget</div>
              </div>
              
              <div className="text-center p-3 rounded-lg bg-muted/50">
                <div className="text-lg font-bold">
                  {formData.goals?.targetConversions || 0}
                </div>
                <div className="text-xs text-muted-foreground">Target Conversions</div>
              </div>
              
              <div className="text-center p-3 rounded-lg bg-muted/50">
                <div className="text-lg font-bold">
                  {formData.goals?.targetEngagementRate || 0}%
                </div>
                <div className="text-xs text-muted-foreground">Target Engagement</div>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Action Buttons */}
        <Card>
          <CardHeader>
            <CardTitle className="text-base flex items-center gap-2">
              <CheckCircle2 className="h-4 w-4" />
              Ready to Create
            </CardTitle>
            <CardDescription>
              Your campaign is ready to be created. You can save as draft or create the campaign now.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="flex flex-col sm:flex-row gap-3">
              {onSaveDraft && (
                <Button
                  data-testid="save-draft-button"
                  variant="outline"
                  onClick={onSaveDraft}
                  className="flex items-center gap-2"
                >
                  <Save className="h-4 w-4" />
                  Save as Draft
                </Button>
              )}
              
              <div className="text-sm text-muted-foreground sm:ml-auto sm:mr-0">
                Click "Create Campaign" in the navigation to finalize and create your campaign.
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      <div className="rounded-lg bg-green-50 border border-green-200 p-4">
        <div className="flex items-start gap-3">
          <CheckCircle2 className="h-5 w-5 text-green-600 mt-0.5" />
          <div className="text-sm">
            <p className="font-medium text-green-800">Campaign Ready</p>
            <p className="text-green-700">
              All required fields are completed. Your campaign is ready to be created.
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}