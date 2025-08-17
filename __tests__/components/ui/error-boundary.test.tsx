import { describe, it, expect, beforeEach, afterEach, jest } from '@jest/globals'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import React from 'react'
import { ErrorBoundary, SimpleErrorFallback } from '@/components/ui/error-boundary'

// Component that throws an error
function ThrowError({ shouldThrow }: { shouldThrow: boolean }) {
  if (shouldThrow) {
    throw new Error('Test error message')
  }
  return <div>No error</div>
}

// Component that throws an error with stack trace
function ThrowErrorWithStack({ shouldThrow }: { shouldThrow: boolean }) {
  if (shouldThrow) {
    const error = new Error('Test error with stack')
    error.stack = 'Error: Test error with stack\n    at ThrowErrorWithStack\n    at ErrorBoundary'
    throw error
  }
  return <div>No error</div>
}

// Custom fallback component for testing
function CustomErrorFallback({ error, resetError }: { error: Error; resetError: () => void }) {
  return (
    <div>
      <h1>Custom Error</h1>
      <p>{error.message}</p>
      <button onClick={resetError}>Reset Custom</button>
    </div>
  )
}

describe('ErrorBoundary', () => {
  // Mock console.error to avoid noise in test output
  const originalConsoleError = console.error
  let consoleErrorSpy: jest.SpiedFunction<typeof console.error>

  beforeEach(() => {
    consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})
  })

  afterEach(() => {
    consoleErrorSpy.mockRestore()
  })

  it('should render children when there is no error', () => {
    render(
      <ErrorBoundary>
        <ThrowError shouldThrow={false} />
      </ErrorBoundary>
    )

    expect(screen.getByText('No error')).toBeInTheDocument()
  })

  it('should render default error fallback when error occurs', () => {
    render(
      <ErrorBoundary>
        <ThrowError shouldThrow={true} />
      </ErrorBoundary>
    )

    expect(screen.getByText('Something went wrong')).toBeInTheDocument()
    expect(screen.getByText(/An error occurred while rendering/)).toBeInTheDocument()
    expect(screen.getByText('Try Again')).toBeInTheDocument()
    expect(screen.getByText('Refresh Page')).toBeInTheDocument()
  })

  it('should display error message in details', async () => {
    const user = userEvent.setup()
    render(
      <ErrorBoundary>
        <ThrowError shouldThrow={true} />
      </ErrorBoundary>
    )

    const detailsElement = screen.getByText('Error details')
    await user.click(detailsElement)

    expect(screen.getByText(/Test error message/)).toBeInTheDocument()
  })

  it('should display error stack trace when available', async () => {
    const user = userEvent.setup()
    render(
      <ErrorBoundary>
        <ThrowErrorWithStack shouldThrow={true} />
      </ErrorBoundary>
    )

    const detailsElement = screen.getByText('Error details')
    await user.click(detailsElement)

    expect(screen.getByText(/Error: Test error with stack/)).toBeInTheDocument()
    expect(screen.getByText(/at ThrowErrorWithStack/)).toBeInTheDocument()
  })

  it('should reset error state when try again is clicked', async () => {
    const user = userEvent.setup()
    
    let shouldThrow = true
    
    function TestComponent() {
      return <ThrowError shouldThrow={shouldThrow} />
    }

    const { rerender } = render(
      <ErrorBoundary>
        <TestComponent />
      </ErrorBoundary>
    )

    // Should show error initially
    expect(screen.getByText('Something went wrong')).toBeInTheDocument()

    // Change the condition so it won't throw after reset
    shouldThrow = false

    const tryAgainButton = screen.getByText('Try Again')
    await user.click(tryAgainButton)

    // After reset, should render the component in non-error state
    await waitFor(() => {
      expect(screen.getByText('No error')).toBeInTheDocument()
    })
  })

  it('should use custom fallback component when provided', () => {
    render(
      <ErrorBoundary fallback={CustomErrorFallback}>
        <ThrowError shouldThrow={true} />
      </ErrorBoundary>
    )

    expect(screen.getByText('Custom Error')).toBeInTheDocument()
    expect(screen.getByText('Test error message')).toBeInTheDocument()
    expect(screen.getByText('Reset Custom')).toBeInTheDocument()
  })

  it('should reset error with custom fallback', async () => {
    const user = userEvent.setup()
    
    let shouldThrow = true
    
    function TestComponent() {
      return <ThrowError shouldThrow={shouldThrow} />
    }

    render(
      <ErrorBoundary fallback={CustomErrorFallback}>
        <TestComponent />
      </ErrorBoundary>
    )

    expect(screen.getByText('Custom Error')).toBeInTheDocument()

    // Change the condition so it won't throw after reset
    shouldThrow = false

    const resetButton = screen.getByText('Reset Custom')
    await user.click(resetButton)

    await waitFor(() => {
      expect(screen.getByText('No error')).toBeInTheDocument()
    })
  })

  it('should call console.error when error is caught', () => {
    render(
      <ErrorBoundary>
        <ThrowError shouldThrow={true} />
      </ErrorBoundary>
    )

    expect(consoleErrorSpy).toHaveBeenCalledWith(
      'Error caught by boundary:',
      expect.any(Error),
      expect.any(Object)
    )
  })

  it.skip('should reload page when refresh page button is clicked', async () => {
    const user = userEvent.setup()
    
    // Mock window.location.reload using jest.spyOn
    const mockReload = jest.fn()
    
    // Replace the reload function directly
    const originalReload = window.location.reload
    window.location.reload = mockReload

    render(
      <ErrorBoundary>
        <ThrowError shouldThrow={true} />
      </ErrorBoundary>
    )

    const refreshButton = screen.getByText('Refresh Page')
    await user.click(refreshButton)

    expect(mockReload).toHaveBeenCalled()
    
    // Restore original function
    window.location.reload = originalReload
  })
})

describe('SimpleErrorFallback', () => {
  const mockError = new Error('Simple test error')
  const mockResetError = jest.fn()

  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('should render error message and try again button', () => {
    render(
      <SimpleErrorFallback error={mockError} resetError={mockResetError} />
    )

    expect(screen.getByText('Error loading content')).toBeInTheDocument()
    expect(screen.getByText('Simple test error')).toBeInTheDocument()
    expect(screen.getByText('Try Again')).toBeInTheDocument()
  })

  it('should call resetError when try again is clicked', async () => {
    const user = userEvent.setup()
    
    render(
      <SimpleErrorFallback error={mockError} resetError={mockResetError} />
    )

    const tryAgainButton = screen.getByText('Try Again')
    await user.click(tryAgainButton)

    expect(mockResetError).toHaveBeenCalledTimes(1)
  })

  it('should show fallback message when error has no message', () => {
    const errorWithoutMessage = new Error()
    errorWithoutMessage.message = ''
    
    render(
      <SimpleErrorFallback error={errorWithoutMessage} resetError={mockResetError} />
    )

    expect(screen.getByText('Something went wrong')).toBeInTheDocument()
  })

  it('should have proper accessibility attributes', () => {
    render(
      <SimpleErrorFallback error={mockError} resetError={mockResetError} />
    )

    const tryAgainButton = screen.getByRole('button', { name: /try again/i })
    expect(tryAgainButton).toBeInTheDocument()
  })
})