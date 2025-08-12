"use client"

import * as React from "react"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Progress } from "@/components/ui/progress"
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible"
import { Separator } from "@/components/ui/separator"
import {
  AlertCircle,
  AlertTriangle,
  Info,
  CheckCircle,
  ChevronDown,
  ChevronUp,
  Lightbulb,
  Settings,
  Plus,
  X,
  Target,
  TrendingUp,
  Shield,
  Zap,
} from "lucide-react"
import { cn } from "@/lib/utils"
import type { JourneyValidationResult, ValidationError } from "./journey-validation"

interface JourneyValidationDisplayProps {
  validation: JourneyValidationResult
  onFixError?: (errorId: string, stageId?: string) => void
  onConfigureStage?: (stageId: string) => void
  className?: string
}

interface ValidationSummaryProps {
  validation: JourneyValidationResult
}

interface ValidationErrorListProps {
  title: string
  errors: ValidationError[]
  icon: React.ReactNode
  variant: "error" | "warning" | "info"
  onFixError?: (errorId: string, stageId?: string) => void
  onConfigureStage?: (stageId: string) => void
}

const getValidationIcon = (type: ValidationError["type"]) => {
  switch (type) {
    case "error":
      return <AlertCircle className="h-4 w-4" />
    case "warning":
      return <AlertTriangle className="h-4 w-4" />
    case "info":
      return <Info className="h-4 w-4" />
    default:
      return <Info className="h-4 w-4" />
  }
}

const getReadinessDetails = (readiness: JourneyValidationResult["readiness"]) => {
  switch (readiness) {
    case "draft":
      return {
        label: "Draft",
        description: "Journey needs fundamental fixes before it can be used",
        color: "text-red-700 bg-red-50 border-red-200",
        icon: <AlertCircle className="h-4 w-4" />,
      }
    case "incomplete":
      return {
        label: "Incomplete",
        description: "Journey has basic structure but needs configuration",
        color: "text-orange-700 bg-orange-50 border-orange-200",
        icon: <AlertTriangle className="h-4 w-4" />,
      }
    case "ready":
      return {
        label: "Ready",
        description: "Journey is functional and ready to launch",
        color: "text-blue-700 bg-blue-50 border-blue-200",
        icon: <Shield className="h-4 w-4" />,
      }
    case "optimized":
      return {
        label: "Optimized",
        description: "Journey is well-configured and optimized",
        color: "text-green-700 bg-green-50 border-green-200",
        icon: <CheckCircle className="h-4 w-4" />,
      }
  }
}

function ValidationSummary({ validation }: ValidationSummaryProps) {
  const readinessInfo = getReadinessDetails(validation.readiness)
  
  return (
    <Card>
      <CardHeader className="pb-4">
        <CardTitle className="flex items-center gap-2">
          <Target className="h-5 w-5" />
          Journey Validation Summary
        </CardTitle>
        <CardDescription>
          Overall health and readiness of your customer journey
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {/* Readiness Status */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Badge className={cn("px-3 py-1", readinessInfo.color)}>
              {readinessInfo.icon}
              <span className="ml-2">{readinessInfo.label}</span>
            </Badge>
          </div>
          <div className="text-right text-sm text-muted-foreground">
            {readinessInfo.description}
          </div>
        </div>

        {/* Completion Progress */}
        <div className="space-y-2">
          <div className="flex items-center justify-between text-sm">
            <span className="font-medium">Completion Progress</span>
            <span className="text-muted-foreground">{validation.completeness}%</span>
          </div>
          <Progress value={validation.completeness} className="h-2" />
        </div>

        {/* Issue Summary */}
        <div className="grid grid-cols-3 gap-4 pt-2">
          <div className="text-center">
            <div className={cn(
              "text-2xl font-bold",
              validation.errors.length === 0 ? "text-green-600" : "text-red-600"
            )}>
              {validation.errors.length}
            </div>
            <div className="text-sm text-muted-foreground">Errors</div>
          </div>
          <div className="text-center">
            <div className={cn(
              "text-2xl font-bold",
              validation.warnings.length === 0 ? "text-green-600" : "text-orange-600"
            )}>
              {validation.warnings.length}
            </div>
            <div className="text-sm text-muted-foreground">Warnings</div>
          </div>
          <div className="text-center">
            <div className="text-2xl font-bold text-blue-600">
              {validation.suggestions.length}
            </div>
            <div className="text-sm text-muted-foreground">Suggestions</div>
          </div>
        </div>

        {/* Quick Actions */}
        {validation.errors.length > 0 && (
          <Alert>
            <AlertCircle className="h-4 w-4" />
            <AlertTitle>Action Required</AlertTitle>
            <AlertDescription>
              Your journey has {validation.errors.length} error{validation.errors.length !== 1 ? 's' : ''} that must be fixed before it can be used effectively.
            </AlertDescription>
          </Alert>
        )}

        {validation.errors.length === 0 && validation.warnings.length === 0 && (
          <Alert>
            <CheckCircle className="h-4 w-4" />
            <AlertTitle>Journey Ready</AlertTitle>
            <AlertDescription>
              Your journey passes all validations and is ready to launch!
            </AlertDescription>
          </Alert>
        )}
      </CardContent>
    </Card>
  )
}

function ValidationErrorList({ 
  title, 
  errors, 
  icon, 
  variant, 
  onFixError, 
  onConfigureStage 
}: ValidationErrorListProps) {
  const [isOpen, setIsOpen] = React.useState(variant === "error") // Auto-expand errors

  if (errors.length === 0) return null

  const getAlertVariant = (variant: ValidationErrorListProps["variant"]) => {
    switch (variant) {
      case "error":
        return "destructive"
      case "warning":
        return "default"
      case "info":
        return "default"
      default:
        return "default"
    }
  }

  const getVariantColors = (variant: ValidationErrorListProps["variant"]) => {
    switch (variant) {
      case "error":
        return "text-red-700 bg-red-50 border-red-200"
      case "warning":
        return "text-orange-700 bg-orange-50 border-orange-200"
      case "info":
        return "text-blue-700 bg-blue-50 border-blue-200"
      default:
        return "text-gray-700 bg-gray-50 border-gray-200"
    }
  }

  return (
    <Collapsible open={isOpen} onOpenChange={setIsOpen}>
      <CollapsibleTrigger asChild>
        <Card className={cn(
          "cursor-pointer hover:shadow-sm transition-shadow",
          getVariantColors(variant)
        )}>
          <CardHeader className="pb-3">
            <CardTitle className="flex items-center justify-between text-base">
              <div className="flex items-center gap-2">
                {icon}
                {title}
                <Badge variant="outline" className="ml-2">
                  {errors.length}
                </Badge>
              </div>
              {isOpen ? <ChevronUp className="h-4 w-4" /> : <ChevronDown className="h-4 w-4" />}
            </CardTitle>
          </CardHeader>
        </Card>
      </CollapsibleTrigger>
      
      <CollapsibleContent>
        <Card className="mt-2 border-l-4 border-l-current">
          <CardContent className="p-4 space-y-3">
            {errors.map((error, index) => (
              <div key={error.id}>
                <Alert variant={getAlertVariant(variant)}>
                  <div className="flex items-start gap-3">
                    {getValidationIcon(error.type)}
                    <div className="flex-1 space-y-2">
                      <AlertTitle className="text-sm font-medium">
                        {error.title}
                      </AlertTitle>
                      <AlertDescription className="text-sm">
                        {error.message}
                      </AlertDescription>
                      {error.suggestion && (
                        <div className="text-sm text-muted-foreground italic">
                          💡 {error.suggestion}
                        </div>
                      )}
                      
                      {/* Action Buttons */}
                      <div className="flex gap-2 pt-2">
                        {error.fixable && onFixError && (
                          <Button
                            size="sm"
                            variant="outline"
                            onClick={() => onFixError(error.id, error.stageId)}
                          >
                            <Zap className="h-3 w-3 mr-1" />
                            Fix
                          </Button>
                        )}
                        {error.stageId && onConfigureStage && (
                          <Button
                            size="sm"
                            variant="outline"
                            onClick={() => onConfigureStage(error.stageId!)}
                          >
                            <Settings className="h-3 w-3 mr-1" />
                            Configure
                          </Button>
                        )}
                      </div>
                    </div>
                  </div>
                </Alert>
                
                {index < errors.length - 1 && <Separator className="my-2" />}
              </div>
            ))}
          </CardContent>
        </Card>
      </CollapsibleContent>
    </Collapsible>
  )
}

export function JourneyValidationDisplay({ 
  validation, 
  onFixError, 
  onConfigureStage, 
  className 
}: JourneyValidationDisplayProps) {
  
  // Don't show validation if there are no stages
  if (validation.completeness === 0 && validation.errors.length === 1 && validation.errors[0].id === "no-stages") {
    return null
  }

  return (
    <div className={cn("space-y-4", className)}>
      {/* Summary Card */}
      <ValidationSummary validation={validation} />

      {/* Error Lists */}
      <div className="space-y-3">
        <ValidationErrorList
          title="Errors (Must Fix)"
          errors={validation.errors}
          icon={<AlertCircle className="h-4 w-4 text-red-600" />}
          variant="error"
          onFixError={onFixError}
          onConfigureStage={onConfigureStage}
        />

        <ValidationErrorList
          title="Warnings (Recommended)"
          errors={validation.warnings}
          icon={<AlertTriangle className="h-4 w-4 text-orange-600" />}
          variant="warning"
          onFixError={onFixError}
          onConfigureStage={onConfigureStage}
        />

        <ValidationErrorList
          title="Optimization Suggestions"
          errors={validation.suggestions}
          icon={<Lightbulb className="h-4 w-4 text-blue-600" />}
          variant="info"
          onFixError={onFixError}
          onConfigureStage={onConfigureStage}
        />
      </div>

      {/* Success State */}
      {validation.isValid && validation.warnings.length === 0 && validation.suggestions.length === 0 && (
        <Card className="bg-green-50 border-green-200">
          <CardContent className="p-4">
            <div className="flex items-center gap-3">
              <div className="rounded-full bg-green-100 p-2">
                <CheckCircle className="h-5 w-5 text-green-600" />
              </div>
              <div>
                <h3 className="font-semibold text-green-800">Perfect Journey!</h3>
                <p className="text-sm text-green-700">
                  Your customer journey is fully optimized and ready for launch.
                </p>
              </div>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  )
}