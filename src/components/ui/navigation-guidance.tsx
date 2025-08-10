"use client"

import * as React from "react"
import { 
  ChevronLeft, 
  ChevronRight, 
  RotateCcw, 
  Save, 
  Eye, 
  AlertCircle, 
  CheckCircle,
  HelpCircle,
  Lightbulb
} from "lucide-react"

import { cn } from "@/lib/utils"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { 
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip"

export interface NavigationAction {
  id: string
  label: string
  icon?: React.ReactNode
  onClick: () => void
  disabled?: boolean
  variant?: "default" | "outline" | "secondary" | "ghost" | "destructive"
  tooltip?: string
  loading?: boolean
}

export interface NavigationGuidanceProps {
  currentStep: number
  totalSteps: number
  onPrevious?: () => void
  onNext?: () => void
  onSave?: () => void
  onReset?: () => void
  onPreview?: () => void
  canGoNext?: boolean
  canGoPrevious?: boolean
  isLoading?: boolean
  customActions?: NavigationAction[]
  showStepInfo?: boolean
  stepTitle?: string
  stepDescription?: string | undefined
  helpContent?: React.ReactNode
  tips?: string[]
  validationStatus?: "valid" | "invalid" | "warning" | "pending"
  className?: string
}

export interface StepGuidanceProps {
  title: string
  description?: string | undefined
  helpContent?: React.ReactNode
  tips?: string[]
  status?: "completed" | "current" | "upcoming" | "error"
  estimatedTime?: string
  requiredFields?: string[]
  optionalFields?: string[]
  className?: string
}

function NavigationGuidance({
  currentStep,
  totalSteps,
  onPrevious,
  onNext,
  onSave,
  onReset,
  onPreview,
  canGoNext = true,
  canGoPrevious = true,
  isLoading = false,
  customActions = [],
  showStepInfo = true,
  stepTitle,
  stepDescription,
  helpContent,
  tips = [],
  validationStatus = "pending",
  className,
}: NavigationGuidanceProps) {
  const isFirstStep = currentStep === 0
  const isLastStep = currentStep === totalSteps - 1
  const progressPercentage = ((currentStep + 1) / totalSteps) * 100

  const statusIcons = {
    valid: <CheckCircle className="w-4 h-4 text-green-600" />,
    invalid: <AlertCircle className="w-4 h-4 text-destructive" />,
    warning: <AlertCircle className="w-4 h-4 text-yellow-600" />,
    pending: null,
  }

  return (
    <TooltipProvider>
      <div className={cn("space-y-4", className)}>
        {/* Step Information Header */}
        {showStepInfo && (
          <div className="flex items-center justify-between p-4 bg-muted/50 rounded-lg">
            <div className="flex-1">
              <div className="flex items-center gap-2 mb-1">
                <h2 className="font-semibold text-lg">
                  {stepTitle || `Step ${currentStep + 1}`}
                </h2>
                {statusIcons[validationStatus]}
                <Badge variant="outline" className="text-xs">
                  {currentStep + 1} of {totalSteps}
                </Badge>
              </div>
              {stepDescription && (
                <p className="text-sm text-muted-foreground">
                  {stepDescription}
                </p>
              )}
            </div>
            
            {/* Progress indicator */}
            <div className="text-right">
              <div className="text-sm text-muted-foreground mb-1">
                Progress
              </div>
              <div className="text-2xl font-bold text-primary">
                {Math.round(progressPercentage)}%
              </div>
            </div>
          </div>
        )}

        {/* Help Content */}
        {helpContent && (
          <div className="p-4 bg-blue-50 border border-blue-200 rounded-lg">
            <div className="flex items-start gap-2">
              <HelpCircle className="w-5 h-5 text-blue-600 mt-0.5 shrink-0" />
              <div className="flex-1">
                {helpContent}
              </div>
            </div>
          </div>
        )}

        {/* Tips */}
        {tips.length > 0 && (
          <div className="p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
            <div className="flex items-start gap-2">
              <Lightbulb className="w-5 h-5 text-yellow-600 mt-0.5 shrink-0" />
              <div className="flex-1">
                <h3 className="font-medium text-yellow-800 mb-2">Tips</h3>
                <ul className="text-sm text-yellow-700 space-y-1">
                  {tips.map((tip, index) => (
                    <li key={index} className="flex items-start gap-1">
                      <span className="text-yellow-600 mt-1">•</span>
                      <span>{tip}</span>
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          </div>
        )}

        {/* Navigation Controls */}
        <div className="flex items-center justify-between p-4 bg-background border rounded-lg">
          {/* Primary Navigation */}
          <div className="flex items-center gap-2">
            <Tooltip>
              <TooltipTrigger asChild>
                <Button
                  type="button"
                  variant="outline"
                  onClick={onPrevious}
                  disabled={isFirstStep || !canGoPrevious || isLoading}
                  className="flex items-center gap-2"
                >
                  <ChevronLeft className="w-4 h-4" />
                  Previous
                </Button>
              </TooltipTrigger>
              <TooltipContent>
                {isFirstStep ? "Already at first step" : "Go to previous step"}
              </TooltipContent>
            </Tooltip>

            <Tooltip>
              <TooltipTrigger asChild>
                <Button
                  type="button"
                  onClick={onNext}
                  disabled={!canGoNext || isLoading}
                  className="flex items-center gap-2"
                >
                  {isLastStep ? "Complete" : "Next"}
                  {!isLastStep && <ChevronRight className="w-4 h-4" />}
                </Button>
              </TooltipTrigger>
              <TooltipContent>
                {isLastStep ? "Complete the process" : "Go to next step"}
              </TooltipContent>
            </Tooltip>
          </div>

          {/* Secondary Actions */}
          <div className="flex items-center gap-2">
            {/* Save Action */}
            {onSave && (
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={onSave}
                    disabled={isLoading}
                    className="flex items-center gap-2"
                  >
                    <Save className="w-4 h-4" />
                    Save
                  </Button>
                </TooltipTrigger>
                <TooltipContent>Save current progress</TooltipContent>
              </Tooltip>
            )}

            {/* Preview Action */}
            {onPreview && (
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={onPreview}
                    disabled={isLoading}
                    className="flex items-center gap-2"
                  >
                    <Eye className="w-4 h-4" />
                    Preview
                  </Button>
                </TooltipTrigger>
                <TooltipContent>Preview your work</TooltipContent>
              </Tooltip>
            )}

            {/* Reset Action */}
            {onReset && (
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={onReset}
                    disabled={isLoading}
                    className="flex items-center gap-2 text-destructive hover:text-destructive"
                  >
                    <RotateCcw className="w-4 h-4" />
                    Reset
                  </Button>
                </TooltipTrigger>
                <TooltipContent>Reset to initial state</TooltipContent>
              </Tooltip>
            )}

            {/* Custom Actions */}
            {customActions.map((action) => (
              <Tooltip key={action.id}>
                <TooltipTrigger asChild>
                  <Button
                    type="button"
                    variant={action.variant || "ghost"}
                    size="sm"
                    onClick={action.onClick}
                    disabled={action.disabled || isLoading}
                    className="flex items-center gap-2"
                  >
                    {action.icon}
                    {action.label}
                  </Button>
                </TooltipTrigger>
                {action.tooltip && (
                  <TooltipContent>{action.tooltip}</TooltipContent>
                )}
              </Tooltip>
            ))}
          </div>
        </div>
      </div>
    </TooltipProvider>
  )
}

function StepGuidance({
  title,
  description,
  helpContent,
  tips = [],
  status = "current",
  estimatedTime,
  requiredFields = [],
  optionalFields = [],
  className,
}: StepGuidanceProps) {
  const statusStyles = {
    completed: "bg-green-50 border-green-200",
    current: "bg-blue-50 border-blue-200",
    upcoming: "bg-gray-50 border-gray-200",
    error: "bg-red-50 border-red-200",
  }

  const statusIcons = {
    completed: <CheckCircle className="w-5 h-5 text-green-600" />,
    current: <HelpCircle className="w-5 h-5 text-blue-600" />,
    upcoming: <HelpCircle className="w-5 h-5 text-gray-400" />,
    error: <AlertCircle className="w-5 h-5 text-red-600" />,
  }

  return (
    <div className={cn(
      "p-4 border rounded-lg",
      statusStyles[status],
      className
    )}>
      {/* Header */}
      <div className="flex items-start gap-3 mb-3">
        {statusIcons[status]}
        <div className="flex-1">
          <h3 className="font-semibold text-lg mb-1">{title}</h3>
          {description && (
            <p className="text-sm text-muted-foreground">{description}</p>
          )}
          {estimatedTime && (
            <p className="text-xs text-muted-foreground mt-1">
              Estimated time: {estimatedTime}
            </p>
          )}
        </div>
      </div>

      {/* Required/Optional Fields */}
      {(requiredFields.length > 0 || optionalFields.length > 0) && (
        <div className="mb-3 grid grid-cols-1 sm:grid-cols-2 gap-4">
          {requiredFields.length > 0 && (
            <div>
              <h4 className="text-sm font-medium mb-2">Required Fields</h4>
              <ul className="text-xs space-y-1">
                {requiredFields.map((field, index) => (
                  <li key={index} className="flex items-center gap-1">
                    <span className="w-1 h-1 bg-red-500 rounded-full"></span>
                    {field}
                  </li>
                ))}
              </ul>
            </div>
          )}
          
          {optionalFields.length > 0 && (
            <div>
              <h4 className="text-sm font-medium mb-2">Optional Fields</h4>
              <ul className="text-xs space-y-1">
                {optionalFields.map((field, index) => (
                  <li key={index} className="flex items-center gap-1">
                    <span className="w-1 h-1 bg-gray-400 rounded-full"></span>
                    {field}
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      )}

      {/* Help Content */}
      {helpContent && (
        <div className="mb-3">
          {helpContent}
        </div>
      )}

      {/* Tips */}
      {tips.length > 0 && (
        <div className="text-sm">
          <h4 className="font-medium mb-2 flex items-center gap-1">
            <Lightbulb className="w-4 h-4" />
            Tips
          </h4>
          <ul className="space-y-1">
            {tips.map((tip, index) => (
              <li key={index} className="flex items-start gap-1">
                <span className="text-muted-foreground mt-1">•</span>
                <span>{tip}</span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  )
}

export { NavigationGuidance, StepGuidance }