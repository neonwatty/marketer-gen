"use client"

import * as React from "react"
import { Check, ChevronLeft, ChevronRight } from "lucide-react"

import { cn } from "@/lib/utils"
import { Button } from "@/components/ui/button"
import { Progress } from "@/components/ui/progress"
import { Badge } from "@/components/ui/badge"

export interface StepperStep {
  id: string
  title: string
  description?: string
  isCompleted?: boolean
  isError?: boolean
  isOptional?: boolean
}

export interface StepperNavigationProps {
  steps: StepperStep[]
  currentStep: number
  onStepChange?: (stepIndex: number) => void
  onNext?: () => void
  onPrevious?: () => void
  onComplete?: () => void
  canGoNext?: boolean
  canGoPrevious?: boolean
  showProgress?: boolean
  showStepNumbers?: boolean
  orientation?: "horizontal" | "vertical"
  className?: string
  children?: React.ReactNode
}

function StepperNavigation({
  steps,
  currentStep,
  onStepChange,
  onNext,
  onPrevious,
  onComplete,
  canGoNext = true,
  canGoPrevious = true,
  showProgress = true,
  showStepNumbers = true,
  orientation = "horizontal",
  className,
  children,
}: StepperNavigationProps) {
  const progressPercentage = ((currentStep) / (steps.length - 1)) * 100

  const isLastStep = currentStep === steps.length - 1
  const isFirstStep = currentStep === 0

  const handleStepClick = (stepIndex: number) => {
    if (onStepChange && stepIndex <= currentStep) {
      onStepChange(stepIndex)
    }
  }

  const handleNext = () => {
    if (isLastStep && onComplete) {
      onComplete()
    } else if (onNext) {
      onNext()
    } else if (onStepChange && currentStep < steps.length - 1) {
      onStepChange(currentStep + 1)
    }
  }

  const handlePrevious = () => {
    if (onPrevious) {
      onPrevious()
    } else if (onStepChange && currentStep > 0) {
      onStepChange(currentStep - 1)
    }
  }

  return (
    <div className={cn("w-full", className)}>
      {/* Progress Bar */}
      {showProgress && (
        <div className="mb-8">
          <Progress value={progressPercentage} className="h-2" />
          <div className="flex justify-between mt-2 text-sm text-muted-foreground">
            <span>Step {currentStep + 1} of {steps.length}</span>
            <span>{Math.round(progressPercentage)}% Complete</span>
          </div>
        </div>
      )}

      {/* Steps Navigation */}
      <div className={cn(
        "mb-8",
        orientation === "vertical" ? "flex flex-col space-y-4" : "flex flex-wrap gap-2 sm:gap-4"
      )}>
        {steps.map((step, index) => {
          const isActive = index === currentStep
          const isCompleted = index < currentStep || step.isCompleted
          const isError = step.isError && index === currentStep
          const isClickable = index <= currentStep && onStepChange

          return (
            <div
              key={step.id}
              className={cn(
                "flex items-center",
                orientation === "vertical" ? "w-full" : "flex-1 min-w-0",
                isClickable && "cursor-pointer"
              )}
              onClick={() => isClickable && handleStepClick(index)}
            >
              {/* Step Indicator */}
              <div className="flex items-center">
                <div
                  className={cn(
                    "flex items-center justify-center w-8 h-8 rounded-full border-2 transition-all",
                    isCompleted && !isError
                      ? "bg-primary border-primary text-primary-foreground"
                      : isActive && !isError
                      ? "border-primary text-primary bg-background"
                      : isError
                      ? "border-destructive text-destructive bg-background"
                      : "border-muted-foreground/30 text-muted-foreground bg-background",
                    isClickable && "hover:border-primary/70"
                  )}
                >
                  {isCompleted && !isError ? (
                    <Check className="w-4 h-4" />
                  ) : showStepNumbers ? (
                    <span className="text-sm font-medium">{index + 1}</span>
                  ) : null}
                </div>

                {/* Step Content */}
                <div className={cn(
                  "ml-3",
                  orientation === "vertical" ? "flex-1" : "hidden sm:block"
                )}>
                  <div className="flex items-center gap-2">
                    <h3
                      className={cn(
                        "text-sm font-medium",
                        isActive ? "text-foreground" : "text-muted-foreground"
                      )}
                    >
                      {step.title}
                    </h3>
                    {step.isOptional && (
                      <Badge variant="outline" className="text-xs">
                        Optional
                      </Badge>
                    )}
                    {isError && (
                      <Badge variant="destructive" className="text-xs">
                        Error
                      </Badge>
                    )}
                  </div>
                  {step.description && (
                    <p className="text-xs text-muted-foreground mt-1">
                      {step.description}
                    </p>
                  )}
                </div>
              </div>

              {/* Connector Line - only for horizontal layout */}
              {orientation === "horizontal" && index < steps.length - 1 && (
                <div className="hidden sm:flex flex-1 items-center mx-4">
                  <div
                    className={cn(
                      "h-0.5 flex-1 transition-colors",
                      index < currentStep ? "bg-primary" : "bg-muted-foreground/30"
                    )}
                  />
                </div>
              )}
            </div>
          )
        })}
      </div>

      {/* Step Content */}
      {children && (
        <div className="mb-8">
          {children}
        </div>
      )}

      {/* Navigation Controls */}
      <div className="flex justify-between items-center">
        <Button
          type="button"
          variant="outline"
          onClick={handlePrevious}
          disabled={isFirstStep || !canGoPrevious}
          className="flex items-center gap-2"
        >
          <ChevronLeft className="w-4 h-4" />
          Previous
        </Button>

        <div className="flex items-center gap-2">
          {/* Current Step Indicator for Mobile */}
          <div className="sm:hidden">
            <Badge variant="secondary">
              {currentStep + 1} / {steps.length}
            </Badge>
          </div>

          <Button
            type="button"
            onClick={handleNext}
            disabled={!canGoNext}
            className="flex items-center gap-2"
          >
            {isLastStep ? "Complete" : "Next"}
            {!isLastStep && <ChevronRight className="w-4 h-4" />}
          </Button>
        </div>
      </div>
    </div>
  )
}

export { StepperNavigation }