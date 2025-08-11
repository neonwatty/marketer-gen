import React from "react"
import { AlertCircle, RefreshCw, X } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"

interface ErrorDisplayProps {
  error: Error | string
  title?: string
  onRetry?: () => void
  onDismiss?: () => void
  variant?: "default" | "destructive"
  showDetails?: boolean
}

export function ErrorDisplay({
  error,
  title = "An error occurred",
  onRetry,
  onDismiss,
  variant = "destructive",
  showDetails = false,
}: ErrorDisplayProps) {
  const errorMessage = typeof error === "string" ? error : error.message
  const errorStack = typeof error === "string" ? undefined : error.stack

  return (
    <Alert variant={variant} className="relative">
      <AlertCircle className="h-4 w-4" />
      <AlertTitle className="flex items-center justify-between">
        {title}
        {onDismiss && (
          <Button
            variant="ghost"
            size="sm"
            onClick={onDismiss}
            className="h-auto p-1 hover:bg-transparent"
          >
            <X className="h-4 w-4" />
          </Button>
        )}
      </AlertTitle>
      <AlertDescription className="mt-2 space-y-3">
        <p>{errorMessage}</p>
        
        {showDetails && errorStack && (
          <details className="mt-2">
            <summary className="cursor-pointer text-sm text-muted-foreground hover:text-foreground">
              Technical details
            </summary>
            <pre className="mt-2 p-2 bg-muted rounded text-xs overflow-auto max-h-32 whitespace-pre-wrap">
              {errorStack}
            </pre>
          </details>
        )}

        {onRetry && (
          <Button
            variant="outline"
            size="sm"
            onClick={onRetry}
            className="w-fit"
          >
            <RefreshCw className="h-3 w-3 mr-1" />
            Retry
          </Button>
        )}
      </AlertDescription>
    </Alert>
  )
}

interface InlineErrorProps {
  message: string
  onRetry?: () => void
}

export function InlineError({ message, onRetry }: InlineErrorProps) {
  return (
    <div className="flex items-center justify-between p-2 text-sm text-destructive bg-destructive/10 rounded border border-destructive/20">
      <span className="flex items-center">
        <AlertCircle className="h-4 w-4 mr-2" />
        {message}
      </span>
      {onRetry && (
        <Button
          variant="ghost"
          size="sm"
          onClick={onRetry}
          className="h-auto p-1 text-destructive hover:text-destructive hover:bg-destructive/20"
        >
          <RefreshCw className="h-3 w-3" />
        </Button>
      )}
    </div>
  )
}