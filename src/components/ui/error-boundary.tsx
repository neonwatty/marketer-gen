'use client'

import React from 'react'

import { AlertCircle, RefreshCw } from 'lucide-react'

import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { cn } from '@/lib/utils'

interface ErrorBoundaryProps {
  children: React.ReactNode
  fallback?: React.ComponentType<ErrorFallbackProps>
}

interface ErrorFallbackProps {
  error: Error
  resetError: () => void
}

interface ErrorBoundaryState {
  hasError: boolean
  error?: Error
}

class ErrorBoundaryClass extends React.Component<
  ErrorBoundaryProps,
  ErrorBoundaryState
> {
  constructor(props: ErrorBoundaryProps) {
    super(props)
    this.state = { hasError: false }
  }

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error }
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('Error caught by boundary:', error, errorInfo)
  }

  render() {
    if (this.state.hasError && this.state.error) {
      const FallbackComponent = this.props.fallback || DefaultErrorFallback
      
      return (
        <FallbackComponent
          error={this.state.error}
          resetError={() => this.setState({ hasError: false, error: undefined })}
        />
      )
    }

    return this.props.children
  }
}

function DefaultErrorFallback({ error, resetError }: ErrorFallbackProps) {
  return (
    <Card className={cn("border-destructive")}>
      <CardHeader>
        <CardTitle className={cn("flex items-center gap-2 text-destructive")}>
          <AlertCircle className={cn("h-5 w-5")} />
          Something went wrong
        </CardTitle>
        <CardDescription>
          An error occurred while rendering this component. Please try refreshing or contact support if the problem persists.
        </CardDescription>
      </CardHeader>
      <CardContent className={cn("space-y-4")}>
        <details className={cn("text-sm")}>
          <summary className={cn("cursor-pointer font-medium")}>Error details</summary>
          <pre className={cn("mt-2 whitespace-pre-wrap break-words rounded bg-muted p-2 text-xs")}>
            {error.message}
            {error.stack && (
              <>
                {'\n\n'}
                {error.stack}
              </>
            )}
          </pre>
        </details>
        
        <div className={cn("flex gap-2")}>
          <Button onClick={resetError} variant="outline" size="sm">
            <RefreshCw className={cn("mr-2 h-4 w-4")} />
            Try Again
          </Button>
          <Button 
            onClick={() => window.location.reload()} 
            variant="default" 
            size="sm"
          >
            Refresh Page
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}

// Custom error fallback for specific use cases
export function SimpleErrorFallback({ error, resetError }: ErrorFallbackProps) {
  return (
    <div className={cn("flex min-h-[200px] items-center justify-center")}>
      <div className={cn("text-center space-y-4")}>
        <AlertCircle className={cn("mx-auto h-12 w-12 text-destructive")} />
        <div>
          <h3 className={cn("text-lg font-medium")}>Error loading content</h3>
          <p className={cn("text-sm text-muted-foreground mt-1")}>
            {error.message || 'Something went wrong'}
          </p>
        </div>
        <Button onClick={resetError} variant="outline" size="sm">
          <RefreshCw className={cn("mr-2 h-4 w-4")} />
          Try Again
        </Button>
      </div>
    </div>
  )
}

export function ErrorBoundary({ children, fallback }: ErrorBoundaryProps) {
  return (
    <ErrorBoundaryClass fallback={fallback}>
      {children}
    </ErrorBoundaryClass>
  )
}