"use client"

import * as React from "react"
import { AlertCircle, CheckCircle, Info, AlertTriangle } from "lucide-react"

import { cn } from "@/lib/utils"
import { Badge } from "@/components/ui/badge"

export type ValidationStatus = "pending" | "valid" | "invalid" | "warning" | "info"

export interface ValidationRule {
  id: string
  field?: string
  message: string
  status: ValidationStatus
  required?: boolean
}

export interface StepValidationResult {
  stepId: string
  isValid: boolean
  canProceed: boolean
  warnings: ValidationRule[]
  errors: ValidationRule[]
  info: ValidationRule[]
}

export interface StepValidationProps {
  stepId: string
  validationRules: ValidationRule[]
  showSummary?: boolean
  className?: string
}

export interface ValidationSummaryProps {
  validationResults: StepValidationResult[]
  currentStep?: number
  className?: string
}

function StepValidation({
  stepId,
  validationRules,
  showSummary = true,
  className,
}: StepValidationProps) {
  const errors = validationRules.filter(rule => rule.status === "invalid")
  const warnings = validationRules.filter(rule => rule.status === "warning")
  const info = validationRules.filter(rule => rule.status === "info")
  const valid = validationRules.filter(rule => rule.status === "valid")

  const hasErrors = errors.length > 0
  const hasWarnings = warnings.length > 0
  const hasInfo = info.length > 0

  if (!showSummary && validationRules.length === 0) {
    return null
  }

  return (
    <div className={cn("space-y-2", className)}>
      {/* Error Messages */}
      {errors.map((rule) => (
        <ValidationMessage
          key={rule.id}
          rule={rule}
          variant="error"
        />
      ))}

      {/* Warning Messages */}
      {warnings.map((rule) => (
        <ValidationMessage
          key={rule.id}
          rule={rule}
          variant="warning"
        />
      ))}

      {/* Info Messages */}
      {info.map((rule) => (
        <ValidationMessage
          key={rule.id}
          rule={rule}
          variant="info"
        />
      ))}

      {/* Success Message */}
      {!hasErrors && !hasWarnings && valid.length > 0 && (
        <ValidationMessage
          rule={{
            id: "success",
            message: "All validation checks passed",
            status: "valid"
          }}
          variant="success"
        />
      )}

      {/* Validation Summary */}
      {showSummary && validationRules.length > 0 && (
        <div className="mt-4 p-3 bg-muted/50 rounded-md">
          <div className="flex items-center gap-4 text-sm">
            <div className="flex items-center gap-2">
              {hasErrors ? (
                <AlertCircle className="w-4 h-4 text-destructive" />
              ) : (
                <CheckCircle className="w-4 h-4 text-green-600" />
              )}
              <span className={hasErrors ? "text-destructive" : "text-green-600"}>
                {hasErrors ? "Has Issues" : "Valid"}
              </span>
            </div>
            
            {errors.length > 0 && (
              <Badge variant="destructive" className="text-xs">
                {errors.length} Error{errors.length > 1 ? "s" : ""}
              </Badge>
            )}
            
            {warnings.length > 0 && (
              <Badge variant="secondary" className="text-xs bg-yellow-100 text-yellow-800">
                {warnings.length} Warning{warnings.length > 1 ? "s" : ""}
              </Badge>
            )}
          </div>
        </div>
      )}
    </div>
  )
}

interface ValidationMessageProps {
  rule: ValidationRule
  variant: "error" | "warning" | "info" | "success"
}

function ValidationMessage({ rule, variant }: ValidationMessageProps) {
  const variantStyles = {
    error: "border-destructive/50 bg-destructive/10 text-destructive",
    warning: "border-yellow-500/50 bg-yellow-50 text-yellow-800",
    info: "border-blue-500/50 bg-blue-50 text-blue-800",
    success: "border-green-500/50 bg-green-50 text-green-800",
  }

  const iconMap = {
    error: AlertCircle,
    warning: AlertTriangle,
    info: Info,
    success: CheckCircle,
  }

  const Icon = iconMap[variant]

  return (
    <div className={cn(
      "flex items-start gap-2 p-3 rounded-md border text-sm",
      variantStyles[variant]
    )}>
      <Icon className="w-4 h-4 mt-0.5 shrink-0" />
      <div className="flex-1">
        <p>{rule.message}</p>
        {rule.field && (
          <p className="text-xs opacity-75 mt-1">
            Field: {rule.field}
          </p>
        )}
      </div>
    </div>
  )
}

function ValidationSummary({
  validationResults,
  currentStep,
  className,
}: ValidationSummaryProps) {
  const totalSteps = validationResults.length
  const validSteps = validationResults.filter(result => result.isValid).length
  const stepsWithErrors = validationResults.filter(result => result.errors.length > 0).length
  const stepsWithWarnings = validationResults.filter(result => result.warnings.length > 0).length

  return (
    <div className={cn("p-4 bg-card border rounded-lg", className)}>
      <h3 className="font-semibold mb-4">Validation Summary</h3>
      
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-4">
        <div className="text-center">
          <div className="text-2xl font-bold text-green-600">{validSteps}</div>
          <div className="text-xs text-muted-foreground">Valid Steps</div>
        </div>
        
        <div className="text-center">
          <div className="text-2xl font-bold text-destructive">{stepsWithErrors}</div>
          <div className="text-xs text-muted-foreground">With Errors</div>
        </div>
        
        <div className="text-center">
          <div className="text-2xl font-bold text-yellow-600">{stepsWithWarnings}</div>
          <div className="text-xs text-muted-foreground">With Warnings</div>
        </div>
        
        <div className="text-center">
          <div className="text-2xl font-bold">{totalSteps}</div>
          <div className="text-xs text-muted-foreground">Total Steps</div>
        </div>
      </div>

      {/* Step-by-step breakdown */}
      <div className="space-y-2">
        {validationResults.map((result, index) => (
          <div
            key={result.stepId}
            className={cn(
              "flex items-center justify-between p-2 rounded text-sm",
              index === currentStep && "bg-primary/10 border border-primary/20",
              !index === currentStep && "bg-muted/30"
            )}
          >
            <div className="flex items-center gap-2">
              <span className="font-medium">Step {index + 1}</span>
              {result.isValid ? (
                <CheckCircle className="w-4 h-4 text-green-600" />
              ) : (
                <AlertCircle className="w-4 h-4 text-destructive" />
              )}
            </div>
            
            <div className="flex items-center gap-2">
              {result.errors.length > 0 && (
                <Badge variant="destructive" className="text-xs">
                  {result.errors.length}
                </Badge>
              )}
              {result.warnings.length > 0 && (
                <Badge variant="secondary" className="text-xs bg-yellow-100 text-yellow-800">
                  {result.warnings.length}
                </Badge>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}

// Hook for managing step validation
export function useStepValidation(steps: string[], validationRules: Record<string, ValidationRule[]>) {
  const [validationResults, setValidationResults] = React.useState<StepValidationResult[]>([])

  const validateStep = React.useCallback((stepId: string): StepValidationResult => {
    const rules = validationRules[stepId] || []
    const errors = rules.filter(rule => rule.status === "invalid")
    const warnings = rules.filter(rule => rule.status === "warning")
    const info = rules.filter(rule => rule.status === "info")

    return {
      stepId,
      isValid: errors.length === 0,
      canProceed: errors.length === 0,
      errors,
      warnings,
      info,
    }
  }, [validationRules])

  const validateAllSteps = React.useCallback(() => {
    const results = steps.map(stepId => validateStep(stepId))
    setValidationResults(results)
    return results
  }, [steps, validateStep])

  React.useEffect(() => {
    validateAllSteps()
  }, [validateAllSteps])

  return {
    validationResults,
    validateStep,
    validateAllSteps,
    canProceedToStep: (stepIndex: number) => {
      if (stepIndex === 0) return true
      return validationResults
        .slice(0, stepIndex)
        .every(result => result.canProceed)
    }
  }
}

export { StepValidation, ValidationSummary }