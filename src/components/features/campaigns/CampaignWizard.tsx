'use client'

import { useCallback,useState, useMemo } from 'react'
import * as React from 'react'
import { FormProvider,useForm } from 'react-hook-form'

import * as z from 'zod'

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'

import { BasicInfoStep } from './wizard-steps/BasicInfoStep'
import { GoalsKPIsStep } from './wizard-steps/GoalsKPIsStep'
import { ReviewStep } from './wizard-steps/ReviewStep'
import { TargetAudienceStep } from './wizard-steps/TargetAudienceStep'
import { TemplateSelectionStep } from './wizard-steps/TemplateSelectionStep'
import { CampaignWizardNav, type WizardStep } from './CampaignWizardNav'

// Define the complete form schema
const campaignFormSchema = z.object({
  // Basic Info
  name: z.string().min(1, 'Campaign name is required').max(100, 'Name too long'),
  description: z.string().min(1, 'Description is required').max(500, 'Description too long'),
  startDate: z.string().min(1, 'Start date is required'),
  endDate: z.string().min(1, 'End date is required'),
  
  // Journey Template
  templateId: z.string().min(1, 'Please select a journey template'),
  templateCustomization: z.object({
    settings: z.record(z.string(), z.any()).optional(),
  }).optional(),
  
  // Target Audience
  targetAudience: z.object({
    demographics: z.object({
      ageRange: z.array(z.number()).optional(),
      gender: z.array(z.string()).optional(),
      locations: z.array(z.string()).optional(),
    }).optional(),
    segments: z.array(z.string()).optional(),
    estimatedSize: z.number().optional(),
  }).optional(),
  
  // Goals & KPIs
  goals: z.object({
    primary: z.string().min(1, 'Primary goal is required'),
    budget: z.number().min(0, 'Budget must be positive'),
    targetConversions: z.number().min(1, 'Target conversions required'),
    targetEngagementRate: z.number().min(0).max(100, 'Rate must be 0-100%'),
  }),
  
  // Additional settings
  isDraft: z.boolean().default(true),
})

export type CampaignFormData = z.infer<typeof campaignFormSchema>

interface CampaignWizardProps {
  onSubmit: (data: CampaignFormData) => Promise<void> | void
  onSaveDraft?: (data: Partial<CampaignFormData>) => Promise<void> | void
  initialData?: Partial<CampaignFormData>
  isLoading?: boolean
}

const wizardSteps: WizardStep[] = [
  {
    id: 'basic-info',
    title: 'Basic Info',
    description: 'Set up campaign name, description, and timeline',
    isCompleted: false,
  },
  {
    id: 'template',
    title: 'Journey Template',
    description: 'Choose a journey template that fits your campaign goals',
    isCompleted: false,
  },
  {
    id: 'audience',
    title: 'Target Audience',
    description: 'Define who you want to reach with this campaign',
    isCompleted: false,
    isOptional: true,
  },
  {
    id: 'goals',
    title: 'Goals & KPIs',
    description: 'Set your success metrics and budget',
    isCompleted: false,
  },
  {
    id: 'review',
    title: 'Review',
    description: 'Review and confirm your campaign settings',
    isCompleted: false,
  },
]

export function CampaignWizard({ 
  onSubmit, 
  onSaveDraft,
  initialData,
  isLoading = false 
}: CampaignWizardProps) {
  const [currentStep, setCurrentStep] = useState(0)

  const defaultFormValues = {
    name: initialData?.name || '',
    description: initialData?.description || '',
    startDate: initialData?.startDate || '',
    endDate: initialData?.endDate || '',
    templateId: initialData?.templateId || '',
    isDraft: initialData?.isDraft ?? true,
    goals: {
      primary: initialData?.goals?.primary || '',
      budget: initialData?.goals?.budget ?? 0,
      targetConversions: initialData?.goals?.targetConversions ?? 1,
      targetEngagementRate: initialData?.goals?.targetEngagementRate ?? 0,
    },
  }

  const form = useForm({
    // resolver: zodResolver(campaignFormSchema),
    defaultValues: defaultFormValues,
    mode: 'onChange',
  })

  const { watch, formState: { isValid } } = form

  // Watch specific form fields for step validation instead of all data
  const name = watch('name')
  const description = watch('description')
  const startDate = watch('startDate')
  const endDate = watch('endDate')
  const templateId = watch('templateId')
  const goalsPrimary = watch('goals.primary')
  const goalsBudget = watch('goals.budget')


  const validateStep = useCallback((stepIndex: number): boolean => {
    switch (stepIndex) {
      case 0: // Basic Info
        return !!(name && description && startDate && endDate)
      case 1: // Template Selection
        return !!templateId
      case 2: // Target Audience (optional)
        return true
      case 3: // Goals & KPIs
        return !!(goalsPrimary && (goalsBudget || goalsBudget === 0) && goalsBudget >= 0)
      case 4: // Review
        return isValid
      default:
        return false
    }
  }, [name, description, startDate, endDate, templateId, goalsPrimary, goalsBudget, isValid])

  // Compute steps with completion status using useMemo to avoid infinite loops
  const steps = useMemo(() => {
    return wizardSteps.map((step, index) => {
      let isCompleted = false
      switch (index) {
        case 0: // Basic Info
          isCompleted = !!(name && description && startDate && endDate)
          break
        case 1: // Template Selection
          isCompleted = !!templateId
          break
        case 2: // Target Audience (optional)
          isCompleted = true
          break
        case 3: // Goals & KPIs
          isCompleted = !!(goalsPrimary && (goalsBudget || goalsBudget === 0) && goalsBudget >= 0)
          break
        case 4: // Review
          isCompleted = isValid
          break
        default:
          isCompleted = false
      }
      return {
        ...step,
        isCompleted
      }
    })
  }, [name, description, startDate, endDate, templateId, goalsPrimary, goalsBudget, isValid])

  const handleStepClick = (stepIndex: number) => {
    setCurrentStep(stepIndex)
  }

  const handleNext = () => {
    if (currentStep < steps.length - 1) {
      setCurrentStep(prev => prev + 1)
    } else {
      // Final submission
      form.handleSubmit((data) => onSubmit(data as CampaignFormData))()
    }
  }

  const handlePrevious = () => {
    if (currentStep > 0) {
      setCurrentStep(prev => prev - 1)
    }
  }

  const handleSaveDraft = async () => {
    if (onSaveDraft) {
      await onSaveDraft(form.getValues())
    }
  }

  const renderStep = () => {
    switch (currentStep) {
      case 0:
        return <BasicInfoStep />
      case 1:
        return <TemplateSelectionStep />
      case 2:
        return <TargetAudienceStep />
      case 3:
        return <GoalsKPIsStep />
      case 4:
        return <ReviewStep onSaveDraft={handleSaveDraft} />
      default:
        return null
    }
  }

  return (
    <FormProvider {...form}>
      <div className="mx-auto max-w-4xl space-y-8">
        <Card>
          <CardHeader>
            <CardTitle>Create New Campaign</CardTitle>
          </CardHeader>
          <CardContent>
            <CampaignWizardNav
              steps={steps}
              currentStep={currentStep}
              onStepClick={handleStepClick}
              onNext={handleNext}
              onPrevious={handlePrevious}
              isNextDisabled={!validateStep(currentStep) || isLoading}
              isPreviousDisabled={currentStep === 0 || isLoading}
            />
          </CardContent>
        </Card>

        <Card>
          <CardContent className="pt-6">
            {renderStep()}
          </CardContent>
        </Card>
      </div>
    </FormProvider>
  )
}