'use client'

import { CheckCircle2, Circle } from 'lucide-react'

import { Button } from '@/components/ui/button'
import { Progress } from '@/components/ui/progress'
import { cn } from '@/lib/utils'

export interface WizardStep {
  id: string
  title: string
  description: string
  isCompleted: boolean
  isOptional?: boolean
}

interface CampaignWizardNavProps {
  steps: WizardStep[]
  currentStep: number
  onStepClick: (stepIndex: number) => void
  onNext: () => void
  onPrevious: () => void
  isNextDisabled?: boolean
  isPreviousDisabled?: boolean
  nextLabel?: string
  previousLabel?: string
  showProgress?: boolean
}

export function CampaignWizardNav({
  steps,
  currentStep,
  onStepClick,
  onNext,
  onPrevious,
  isNextDisabled = false,
  isPreviousDisabled = false,
  nextLabel = 'Next',
  previousLabel = 'Previous',
  showProgress = true,
}: CampaignWizardNavProps) {
  const progress = ((currentStep + 1) / steps.length) * 100
  const isLastStep = currentStep === steps.length - 1

  const canNavigateToStep = (stepIndex: number) => {
    // Can always go back to previous steps
    if (stepIndex < currentStep) return true
    
    // Can go to next step if current step is completed
    if (stepIndex === currentStep + 1) {
      return steps[currentStep]?.isCompleted
    }
    
    // Can stay on current step
    return stepIndex === currentStep
  }

  return (
    <div className="space-y-6">
      {/* Progress Indicator */}
      {showProgress && (
        <div className="space-y-2">
          <div className="flex justify-between text-sm">
            <span className="text-muted-foreground">
              Step {currentStep + 1} of {steps.length}
            </span>
            <span className="font-medium">{Math.round(progress)}% Complete</span>
          </div>
          <Progress value={progress} className="h-2" />
        </div>
      )}

      {/* Step Navigation */}
      <div className="space-y-4">
        <div className="flex flex-wrap gap-2">
          {steps.map((step, index) => {
            const isCurrent = index === currentStep
            const isCompleted = step.isCompleted
            const canNavigate = canNavigateToStep(index)
            
            return (
              <button
                key={step.id}
                onClick={() => canNavigate && onStepClick(index)}
                disabled={!canNavigate}
                className={cn(
                  'flex items-center gap-2 rounded-lg px-3 py-2 text-sm transition-all',
                  'hover:bg-accent hover:text-accent-foreground',
                  'disabled:pointer-events-none disabled:opacity-50',
                  isCurrent && 'bg-primary text-primary-foreground hover:bg-primary/90',
                  isCompleted && !isCurrent && 'bg-muted text-muted-foreground'
                )}
              >
                {isCompleted ? (
                  <CheckCircle2 className="h-4 w-4" />
                ) : (
                  <Circle className={cn('h-4 w-4', isCurrent && 'fill-current')} />
                )}
                <span className="font-medium">{step.title}</span>
                {step.isOptional && (
                  <span className="text-xs opacity-75">(Optional)</span>
                )}
              </button>
            )
          })}
        </div>

        {/* Current Step Info */}
        <div className="rounded-lg border bg-card p-4">
          <h3 className="font-semibold">{steps[currentStep]?.title}</h3>
          <p className="text-muted-foreground text-sm mt-1">
            {steps[currentStep]?.description}
          </p>
        </div>
      </div>

      {/* Navigation Buttons */}
      <div className="flex justify-between">
        <Button
          variant="outline"
          onClick={onPrevious}
          disabled={isPreviousDisabled}
        >
          {previousLabel}
        </Button>
        
        <Button
          onClick={onNext}
          disabled={isNextDisabled}
          data-testid={isLastStep ? 'create-campaign-final' : 'wizard-next'}
        >
          {isLastStep ? 'Create Campaign' : nextLabel}
        </Button>
      </div>
    </div>
  )
}