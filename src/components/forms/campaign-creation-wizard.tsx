"use client"

import * as React from "react"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { StepperNavigation, type StepperStep } from "@/components/ui/stepper-navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Form } from "@/components/ui/form"
import { 
  campaignWizardSchema,
  type CampaignWizardData,
  campaignTemplates,
  type CampaignTemplate
} from "./campaign-wizard-schemas"
import { CampaignBasicsStep } from "./wizard-steps/campaign-basics-step"
import { AudienceChannelsStep } from "./wizard-steps/audience-channels-step"
import { BudgetScheduleStep } from "./wizard-steps/budget-schedule-step"
import { ContentAssetsStep } from "./wizard-steps/content-assets-step"
import { ReviewFinalizationStep } from "./wizard-steps/review-finalization-step"

export interface CampaignCreationWizardProps {
  onComplete?: (data: CampaignWizardData) => Promise<void> | void
  onCancel?: () => void
  initialData?: Partial<CampaignWizardData>
  className?: string
  isSubmitting?: boolean
}

const wizardSteps: StepperStep[] = [
  {
    id: "basics",
    title: "Campaign Basics",
    description: "Set up campaign name, template, and objectives",
  },
  {
    id: "audience-channels",
    title: "Audience & Channels",
    description: "Define target audience and marketing channels",
  },
  {
    id: "budget-schedule",
    title: "Budget & Schedule",
    description: "Set campaign budget and timeline",
  },
  {
    id: "content-assets",
    title: "Content & Assets",
    description: "Configure content strategy and brand assets",
  },
  {
    id: "review",
    title: "Review & Launch",
    description: "Review settings and launch campaign",
  },
]

export function CampaignCreationWizard({
  onComplete,
  onCancel,
  initialData,
  className,
  isSubmitting = false,
}: CampaignCreationWizardProps) {
  const [currentStep, setCurrentStep] = React.useState(0)
  const [stepErrors, setStepErrors] = React.useState<Record<number, boolean>>({})
  const [internalSubmitting, setInternalSubmitting] = React.useState(false)

  // Initialize form with default values
  const form = useForm<CampaignWizardData>({
    resolver: zodResolver(campaignWizardSchema),
    defaultValues: {
      basics: {
        name: "",
        description: "",
        template: undefined,
        objectives: [],
        ...initialData?.basics,
      },
      audienceChannels: {
        targetAudience: {
          demographics: {},
          customDescription: "",
        },
        channels: [],
        tone: "professional",
        keywords: "",
        ...initialData?.audienceChannels,
      },
      budgetSchedule: {
        budget: {
          total: 0,
          currency: "USD",
        },
        schedule: {
          startDate: new Date(),
          endDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days from now
          timezone: "UTC",
          launchImmediately: false,
        },
        ...initialData?.budgetSchedule,
      },
      contentAssets: {
        contentStrategy: {
          contentTypes: [],
          contentFrequency: "weekly",
        },
        messaging: {
          primaryMessage: "",
          callToAction: "",
        },
        ...initialData?.contentAssets,
      },
      reviewFinalization: {
        campaignReview: {
          agreedToTerms: false,
          launchPreference: "draft",
          notifications: {
            emailNotifications: true,
            slackNotifications: false,
          },
        },
        ...initialData?.reviewFinalization,
      },
    },
    mode: "onChange",
  })

  // Handle template selection and apply presets
  const handleTemplateChange = (template: CampaignTemplate) => {
    const templateData = campaignTemplates[template]
    if (templateData.presets) {
      // Apply template presets
      if (templateData.presets.objectives) {
        form.setValue("basics.objectives", templateData.presets.objectives as any)
      }
      if (templateData.presets.channels) {
        form.setValue("audienceChannels.channels", templateData.presets.channels as any)
      }
      if (templateData.presets.contentTypes) {
        form.setValue("contentAssets.contentStrategy.contentTypes", templateData.presets.contentTypes as any)
      }
    }
  }

  // Validate current step
  const validateCurrentStep = async (): Promise<boolean> => {
    const stepFields = getStepFields(currentStep)
    const result = await form.trigger(stepFields)
    
    setStepErrors(prev => ({
      ...prev,
      [currentStep]: !result
    }))
    
    return result
  }

  // Get fields for current step validation
  const getStepFields = (step: number): (keyof CampaignWizardData)[] => {
    switch (step) {
      case 0:
        return ["basics"]
      case 1:
        return ["audienceChannels"]
      case 2:
        return ["budgetSchedule"]
      case 3:
        return ["contentAssets"]
      case 4:
        return ["reviewFinalization"]
      default:
        return []
    }
  }

  // Handle step navigation
  const handleNext = async () => {
    const isValid = await validateCurrentStep()
    if (!isValid) return

    if (currentStep < wizardSteps.length - 1) {
      setCurrentStep(currentStep + 1)
    }
  }

  const handlePrevious = () => {
    if (currentStep > 0) {
      setCurrentStep(currentStep - 1)
    }
  }

  const handleStepChange = async (stepIndex: number) => {
    if (stepIndex < currentStep) {
      // Allow going back to previous steps
      setCurrentStep(stepIndex)
    } else if (stepIndex === currentStep + 1) {
      // Allow going to next step if current is valid
      const isValid = await validateCurrentStep()
      if (isValid) {
        setCurrentStep(stepIndex)
      }
    }
  }

  // Handle form completion
  const handleComplete = async () => {
    const isValid = await form.trigger()
    if (!isValid) {
      // Find first invalid step
      for (let i = 0; i < wizardSteps.length; i++) {
        const stepFields = getStepFields(i)
        const stepValid = await form.trigger(stepFields)
        if (!stepValid) {
          setCurrentStep(i)
          setStepErrors(prev => ({ ...prev, [i]: true }))
          break
        }
      }
      return
    }

    setInternalSubmitting(true)
    try {
      const data = form.getValues()
      await onComplete?.(data)
    } catch (error) {
      console.error("Failed to submit campaign:", error)
    } finally {
      setInternalSubmitting(false)
    }
  }

  // Render current step content
  const renderStepContent = () => {
    switch (currentStep) {
      case 0:
        return (
          <CampaignBasicsStep
            form={form}
            onTemplateChange={handleTemplateChange}
          />
        )
      case 1:
        return <AudienceChannelsStep form={form} />
      case 2:
        return <BudgetScheduleStep form={form} />
      case 3:
        return <ContentAssetsStep form={form} />
      case 4:
        return <ReviewFinalizationStep form={form} />
      default:
        return null
    }
  }

  // Update step error states based on form errors
  React.useEffect(() => {
    const errors = form.formState.errors
    const newStepErrors: Record<number, boolean> = {}

    if (errors.basics) newStepErrors[0] = true
    if (errors.audienceChannels) newStepErrors[1] = true
    if (errors.budgetSchedule) newStepErrors[2] = true
    if (errors.contentAssets) newStepErrors[3] = true
    if (errors.reviewFinalization) newStepErrors[4] = true

    setStepErrors(newStepErrors)
  }, [form.formState.errors])

  // Update steps with error states
  const stepsWithErrors = wizardSteps.map((step, index) => ({
    ...step,
    isError: stepErrors[index],
    isCompleted: index < currentStep && !stepErrors[index],
  }))

  return (
    <div className={className}>
      <Form {...form}>
        <form onSubmit={form.handleSubmit(handleComplete)}>
          <Card>
            <CardHeader>
              <CardTitle>Create New Campaign</CardTitle>
              <CardDescription>
                Follow these steps to set up your marketing campaign
              </CardDescription>
            </CardHeader>
            
            <CardContent className="space-y-6">
              <StepperNavigation
                steps={stepsWithErrors}
                currentStep={currentStep}
                onStepChange={handleStepChange}
                onNext={handleNext}
                onPrevious={handlePrevious}
                onComplete={handleComplete}
                canGoNext={!stepErrors[currentStep]}
                canGoPrevious={currentStep > 0}
                isLoading={isSubmitting || internalSubmitting}
                showProgress={true}
                showStepNumbers={true}
              >
                {renderStepContent()}
              </StepperNavigation>
            </CardContent>
          </Card>

          {/* Action buttons outside the stepper for additional control */}
          <div className="flex justify-between items-center mt-6">
            <Button
              type="button"
              variant="outline"
              onClick={onCancel}
            >
              Cancel
            </Button>

            <div className="flex gap-2">
              <Button
                type="button"
                variant="outline"
                onClick={() => {
                  // Save as draft
                  const data = form.getValues()
                  form.setValue("reviewFinalization.campaignReview.launchPreference", "draft")
                  onComplete?.(data)
                }}
              >
                Save as Draft
              </Button>
              
              {currentStep === wizardSteps.length - 1 && (
                <Button
                  type="submit"
                  onClick={() => {
                    form.setValue("reviewFinalization.campaignReview.launchPreference", "immediate")
                  }}
                >
                  Launch Campaign
                </Button>
              )}
            </div>
          </div>
        </form>
      </Form>
    </div>
  )
}