'use client'

import { useCallback, useEffect, useMemo, useRef,useState } from 'react'
import * as React from 'react'
import { FormProvider, useForm } from 'react-hook-form'

import { zodResolver } from '@hookform/resolvers/zod'
import { toast } from 'sonner'
import * as z from 'zod'

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'

import { BasicInfoStep } from './wizard-steps/BasicInfoStep'
import { GoalsKPIsStep } from './wizard-steps/GoalsKPIsStep'
import { ReviewStep } from './wizard-steps/ReviewStep'
import { TargetAudienceStep } from './wizard-steps/TargetAudienceStep'
import { TemplateSelectionStep } from './wizard-steps/TemplateSelectionStep'
import { ContentGenerationStep } from './wizard-steps/ContentGenerationStep'
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
      ageRange: z.array(z.number()),
      gender: z.array(z.string()),
      locations: z.array(z.string()),
    }),
    segments: z.array(z.string()),
    estimatedSize: z.number(),
  }),
  
  // Goals & KPIs
  goals: z.object({
    primary: z.string().min(1, 'Primary goal is required'),
    budget: z.number().min(0, 'Budget must be positive'),
    targetConversions: z.number().min(1, 'Target conversions required'),
    targetEngagementRate: z.number().min(0).max(100, 'Rate must be 0-100%'),
  }),
  
  // Generated Content
  generatedContent: z.array(z.object({
    id: z.string(),
    type: z.string(),
    stage: z.string(),
    content: z.string(),
    variants: z.array(z.any()).optional(),
    compliance: z.object({
      isCompliant: z.boolean(),
      score: z.number(),
      violations: z.array(z.string()),
    }),
    metadata: z.object({
      generatedAt: z.string(),
      wordCount: z.number(),
      charCount: z.number(),
    }),
  })).optional(),
  
  // Brand ID for content generation
  brandId: z.string().optional(),
  
  // Additional settings
  isDraft: z.boolean(),
})

export type CampaignFormData = z.infer<typeof campaignFormSchema>

interface Brand {
  id: string
  name: string
  tagline?: string
  voiceDescription?: string
}

interface CampaignWizardProps {
  onSubmit: (data: CampaignFormData) => Promise<void> | void
  onSaveDraft?: (data: Partial<CampaignFormData>) => Promise<void> | void
  initialData?: Partial<CampaignFormData>
  isLoading?: boolean
  brands: Brand[]
  quickMode?: boolean // Enable quick creation mode for testing
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
    id: 'content',
    title: 'AI Content Generation',
    description: 'Generate brand-aligned content for your campaign',
    isCompleted: false,
    isOptional: true,
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
  isLoading = false,
  brands,
  quickMode = false
}: CampaignWizardProps) {
  const [currentStep, setCurrentStep] = useState(() => {
    // In test environments, always start at step 0
    if (typeof window !== 'undefined' && process.env.NODE_ENV !== 'test') {
      const saved = localStorage.getItem('campaign-wizard-step')
      return saved ? parseInt(saved, 10) : 0
    }
    return 0
  })
  const [lastAutoSave, setLastAutoSave] = useState<Date | null>(null)
  const [hasUnsavedChanges, setHasUnsavedChanges] = useState(false)
  const autoSaveTimeoutRef = useRef<NodeJS.Timeout | null>(null)
  const lastSavedDataRef = useRef<string | null>(null)

  const defaultFormValues = useMemo(() => {
    let savedData: Partial<CampaignFormData> = {}
    
    if (typeof window !== 'undefined' && process.env.NODE_ENV !== 'test') {
      try {
        const saved = localStorage.getItem('campaign-wizard-data')
        if (saved) {
          savedData = JSON.parse(saved)
        }
      } catch (error) {
        console.warn('Failed to parse saved campaign data:', error)
      }
    }

    return {
      name: initialData?.name || savedData?.name || '',
      description: initialData?.description || savedData?.description || '',
      startDate: initialData?.startDate || savedData?.startDate || new Date().toISOString().split('T')[0],
      endDate: initialData?.endDate || savedData?.endDate || new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
      templateId: initialData?.templateId || savedData?.templateId || 'email-marketing',
      isDraft: initialData?.isDraft ?? savedData?.isDraft ?? true,
      targetAudience: {
        demographics: {
          ageRange: initialData?.targetAudience?.demographics?.ageRange || savedData?.targetAudience?.demographics?.ageRange || [],
          gender: initialData?.targetAudience?.demographics?.gender || savedData?.targetAudience?.demographics?.gender || [],
          locations: initialData?.targetAudience?.demographics?.locations || savedData?.targetAudience?.demographics?.locations || [],
        },
        segments: initialData?.targetAudience?.segments || savedData?.targetAudience?.segments || [],
        estimatedSize: initialData?.targetAudience?.estimatedSize || savedData?.targetAudience?.estimatedSize || 0,
      },
      goals: {
        primary: initialData?.goals?.primary || savedData?.goals?.primary || 'brand-awareness',
        budget: initialData?.goals?.budget ?? savedData?.goals?.budget ?? 1000,
        targetConversions: initialData?.goals?.targetConversions ?? savedData?.goals?.targetConversions ?? 1,
        targetEngagementRate: initialData?.goals?.targetEngagementRate ?? savedData?.goals?.targetEngagementRate ?? 0,
      },
      generatedContent: initialData?.generatedContent || savedData?.generatedContent || [],
      brandId: initialData?.brandId || savedData?.brandId || '',
    }
  }, [initialData])

  const form = useForm({
    resolver: zodResolver(campaignFormSchema),
    defaultValues: defaultFormValues,
    mode: 'onChange',
  })

  const { watch, formState: { isValid } } = form
  const allFormData = watch()

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
      case 4: // Content Generation (optional)
        return true
      case 5: // Review
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
        case 4: // Content Generation (optional)
          isCompleted = true
          break
        case 5: // Review
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
    if (typeof window !== 'undefined' && process.env.NODE_ENV !== 'test') {
      localStorage.setItem('campaign-wizard-step', stepIndex.toString())
    }
  }

  const handleNext = () => {
    if (currentStep < steps.length - 1) {
      const nextStep = currentStep + 1
      setCurrentStep(nextStep)
      if (typeof window !== 'undefined' && process.env.NODE_ENV !== 'test') {
        localStorage.setItem('campaign-wizard-step', nextStep.toString())
      }
    } else {
      // Final submission - clear saved data on success
      form.handleSubmit((data) => {
        onSubmit(data as CampaignFormData)
        if (typeof window !== 'undefined' && process.env.NODE_ENV !== 'test') {
          localStorage.removeItem('campaign-wizard-step')
          localStorage.removeItem('campaign-wizard-data')
        }
      })()
    }
  }

  const handlePrevious = () => {
    if (currentStep > 0) {
      const prevStep = currentStep - 1
      setCurrentStep(prevStep)
      if (typeof window !== 'undefined' && process.env.NODE_ENV !== 'test') {
        localStorage.setItem('campaign-wizard-step', prevStep.toString())
      }
    }
  }

  const handleSaveDraft = async () => {
    if (onSaveDraft) {
      const formData = form.getValues()
      await onSaveDraft(formData)
      
      // Update auto-save state after manual save
      setLastAutoSave(new Date())
      setHasUnsavedChanges(false)
      lastSavedDataRef.current = JSON.stringify(formData)
    }
  }

  const handleAutoSave = useCallback(async () => {
    console.log('Auto-save: handleAutoSave called', { hasUnsavedChanges, onSaveDraft: !!onSaveDraft })
    if (onSaveDraft && hasUnsavedChanges) {
      try {
        const formData = form.getValues()
        console.log('Auto-save: Calling onSaveDraft with data:', formData)
        await onSaveDraft(formData)
        setLastAutoSave(new Date())
        setHasUnsavedChanges(false)
        lastSavedDataRef.current = JSON.stringify(formData)
        
        // Show subtle auto-save notification - only for the first few saves to not overwhelm
        if (!lastAutoSave || (new Date().getTime() - lastAutoSave.getTime()) > 300000) { // Show every 5 minutes max
          toast.success('Draft auto-saved', {
            duration: 1500,
            description: `Auto-saved at ${new Date().toLocaleTimeString()}`,
            style: {
              fontSize: '14px',
            }
          })
        }
      } catch (error) {
        console.error('Auto-save failed:', error)
        toast.error('Auto-save failed', {
          duration: 3000,
          description: 'Your changes could not be auto-saved. Please save manually.',
        })
      }
    } else {
      console.log('Auto-save: Skipping auto-save - conditions not met')
    }
  }, [onSaveDraft, hasUnsavedChanges, form])

  // Auto-save effect with localStorage persistence
  useEffect(() => {
    // Clear existing timeout
    if (autoSaveTimeoutRef.current) {
      clearTimeout(autoSaveTimeoutRef.current)
    }

    // Check if form data has changed
    const currentDataString = JSON.stringify(allFormData)
    
    // Initialize if this is the first time
    if (lastSavedDataRef.current === null) {
      lastSavedDataRef.current = currentDataString
      return
    }
    
    const hasChanges = lastSavedDataRef.current !== currentDataString
    
    // Update unsaved changes state
    if (hasChanges !== hasUnsavedChanges) {
      setHasUnsavedChanges(hasChanges)
      console.log('Auto-save: Changes detected:', hasChanges)
    }

    // Save to localStorage for persistence
    if (hasChanges && typeof window !== 'undefined' && process.env.NODE_ENV !== 'test') {
      localStorage.setItem('campaign-wizard-data', currentDataString)
    }

    // Set up new auto-save timeout if there are changes
    if (hasChanges && onSaveDraft) {
      console.log('Auto-save: Setting up auto-save timer')
      autoSaveTimeoutRef.current = setTimeout(() => {
        console.log('Auto-save: Timer triggered, calling handleAutoSave')
        handleAutoSave()
      }, 10000) // Auto-save every 10 seconds for faster testing
    }

    return () => {
      if (autoSaveTimeoutRef.current) {
        clearTimeout(autoSaveTimeoutRef.current)
      }
    }
  }, [allFormData, hasUnsavedChanges, handleAutoSave, onSaveDraft])

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
        return <ContentGenerationStep brands={brands} />
      case 5:
        return <ReviewStep onSaveDraft={handleSaveDraft} />
      default:
        return null
    }
  }

  return (
    <FormProvider {...form}>
      <div className="mx-auto max-w-4xl space-y-8" data-testid="campaign-form">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center justify-between">
              <span>Campaign Wizard</span>
              {/* Enhanced auto-save status indicator */}
              <div className="flex items-center gap-2 text-sm">
                {hasUnsavedChanges && (
                  <div className="flex items-center gap-2 px-2 py-1 bg-yellow-50 border border-yellow-200 rounded-full">
                    <div className="h-2 w-2 bg-yellow-500 rounded-full animate-pulse" />
                    <span className="text-yellow-700 font-medium">Unsaved changes</span>
                  </div>
                )}
                {lastAutoSave && !hasUnsavedChanges && (
                  <div className="flex items-center gap-2 px-2 py-1 bg-green-50 border border-green-200 rounded-full">
                    <div className="h-2 w-2 bg-green-500 rounded-full" />
                    <span className="text-green-700 font-medium">Auto-saved at {lastAutoSave.toLocaleTimeString()}</span>
                  </div>
                )}
              </div>
            </CardTitle>
          </CardHeader>
          <CardContent>
            <CampaignWizardNav
              steps={steps}
              currentStep={currentStep}
              onStepClick={handleStepClick}
              onNext={handleNext}
              onPrevious={handlePrevious}
              isNextDisabled={quickMode ? (!name || !description || isLoading) : (!validateStep(currentStep) || isLoading)}
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