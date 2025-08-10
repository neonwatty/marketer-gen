"use client"

import * as React from "react"
import { cn } from "@/lib/utils"
import { Progress } from "./progress"

interface ProgressBarProps extends React.ComponentProps<"div"> {
  value: number
  max?: number
  label?: string
  description?: string
  showPercentage?: boolean
  showValues?: boolean
  status?: "default" | "success" | "warning" | "error"
  size?: "sm" | "md" | "lg"
  animate?: boolean
  steps?: {
    label: string
    value: number
    completed?: boolean
  }[]
}

const statusColors = {
  default: "bg-primary",
  success: "bg-green-500",
  warning: "bg-yellow-500",
  error: "bg-red-500",
}

const sizeClasses = {
  sm: "h-1.5",
  md: "h-2",
  lg: "h-3",
}

function ProgressBar({
  className,
  value,
  max = 100,
  label,
  description,
  showPercentage = true,
  showValues = false,
  status = "default",
  size = "md",
  animate = true,
  steps,
  ...props
}: ProgressBarProps) {
  const percentage = Math.min(100, Math.max(0, (value / max) * 100))
  const [displayValue, setDisplayValue] = React.useState(animate ? 0 : percentage)

  React.useEffect(() => {
    if (animate && displayValue !== percentage) {
      const timer = setTimeout(() => {
        const step = percentage > displayValue ? 1 : -1
        setDisplayValue((prev) => {
          const next = prev + step
          if (step > 0) {
            return Math.min(next, percentage)
          }
          return Math.max(next, percentage)
        })
      }, 20)
      return () => clearTimeout(timer)
    }
  }, [percentage, displayValue, animate])

  return (
    <div className={cn("space-y-2", className)} {...props}>
      {/* Header with label and value */}
      {(label || showPercentage || showValues) && (
        <div className="flex items-center justify-between text-sm">
          <div className="space-y-1">
            {label && (
              <div className="font-medium text-foreground">{label}</div>
            )}
            {description && (
              <div className="text-xs text-muted-foreground">{description}</div>
            )}
          </div>
          <div className="text-right">
            {showPercentage && (
              <div className="font-medium text-foreground">
                {Math.round(displayValue)}%
              </div>
            )}
            {showValues && (
              <div className="text-xs text-muted-foreground">
                {value} / {max}
              </div>
            )}
          </div>
        </div>
      )}

      {/* Progress bar */}
      <div className="relative">
        <Progress
          value={displayValue}
          className={cn(
            sizeClasses[size],
            "transition-all duration-300 ease-in-out",
            className
          )}
        />
        {/* Custom status color overlay */}
        {status !== "default" && (
          <div
            className={cn(
              "absolute inset-0 rounded-full transition-all duration-300",
              sizeClasses[size]
            )}
          >
            <div
              className={cn(
                "h-full rounded-full transition-all",
                statusColors[status]
              )}
              style={{ width: `${displayValue}%` }}
            />
          </div>
        )}
      </div>

      {/* Steps indicator */}
      {steps && steps.length > 0 && (
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            {steps.map((step, index) => (
              <div
                key={index}
                className="flex flex-col items-center space-y-1 flex-1"
              >
                <div
                  className={cn(
                    "w-3 h-3 rounded-full border-2 transition-colors",
                    step.completed || value >= step.value
                      ? "bg-primary border-primary"
                      : "bg-background border-muted-foreground/30"
                  )}
                />
                <div className="text-xs text-center text-muted-foreground max-w-[60px] leading-tight">
                  {step.label}
                </div>
              </div>
            ))}
          </div>
          
          {/* Connecting line */}
          <div className="relative -mt-8 mx-6">
            <div className="absolute top-6 left-0 right-0 h-0.5 bg-muted-foreground/20" />
            <div
              className="absolute top-6 left-0 h-0.5 bg-primary transition-all duration-500"
              style={{
                width: `${Math.min(
                  100,
                  ((value - (steps[0]?.value || 0)) /
                    ((steps[steps.length - 1]?.value || max) - (steps[0]?.value || 0))) *
                    100
                )}%`,
              }}
            />
          </div>
        </div>
      )}
    </div>
  )
}

export { ProgressBar }
export type { ProgressBarProps }