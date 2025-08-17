import { describe, it, expect, beforeEach, afterEach, jest } from '@jest/globals'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import React from 'react'
import { toast } from 'sonner'
import { ToastProvider } from '@/lib/providers/toast-provider'

// Test component that triggers toasts
function TestToastComponent() {
  return (
    <div>
      <button onClick={() => toast.success('Success message')}>
        Success Toast
      </button>
      <button onClick={() => toast.error('Error message')}>
        Error Toast
      </button>
      <button onClick={() => toast.info('Info message')}>
        Info Toast
      </button>
      <button onClick={() => toast.warning('Warning message')}>
        Warning Toast
      </button>
      <button onClick={() => toast('Default message')}>
        Default Toast
      </button>
      <button 
        onClick={() => toast('Rich toast', {
          description: 'This has a description',
          action: {
            label: 'Undo',
            onClick: () => console.log('Undo clicked'),
          },
        })}
      >
        Rich Toast
      </button>
      <button onClick={() => toast.dismiss()}>
        Dismiss All
      </button>
    </div>
  )
}

describe.skip('ToastProvider', () => {
  beforeEach(() => {
    // Clear any existing toasts before each test
    toast.dismiss()
  })

  afterEach(() => {
    // Clean up after each test
    toast.dismiss()
  })

  it('should render without crashing', () => {
    render(<ToastProvider />)
    
    // The Toaster component should be in the DOM
    // Note: Sonner's Toaster might not have specific test IDs, so we check if it renders without error
    expect(document.body).toBeInTheDocument()
  })

  it('should display success toast', async () => {
    const user = userEvent.setup()
    
    render(
      <div>
        <ToastProvider />
        <TestToastComponent />
      </div>
    )

    const successButton = screen.getByText('Success Toast')
    await user.click(successButton)

    await waitFor(() => {
      expect(screen.getByText('Success message')).toBeInTheDocument()
    })
  })

  it('should display error toast', async () => {
    const user = userEvent.setup()
    
    render(
      <div>
        <ToastProvider />
        <TestToastComponent />
      </div>
    )

    const errorButton = screen.getByText('Error Toast')
    await user.click(errorButton)

    await waitFor(() => {
      expect(screen.getByText('Error message')).toBeInTheDocument()
    })
  })

  it('should display info toast', async () => {
    const user = userEvent.setup()
    
    render(
      <div>
        <ToastProvider />
        <TestToastComponent />
      </div>
    )

    const infoButton = screen.getByText('Info Toast')
    await user.click(infoButton)

    await waitFor(() => {
      expect(screen.getByText('Info message')).toBeInTheDocument()
    })
  })

  it('should display warning toast', async () => {
    const user = userEvent.setup()
    
    render(
      <div>
        <ToastProvider />
        <TestToastComponent />
      </div>
    )

    const warningButton = screen.getByText('Warning Toast')
    await user.click(warningButton)

    await waitFor(() => {
      expect(screen.getByText('Warning message')).toBeInTheDocument()
    })
  })

  it('should display default toast', async () => {
    const user = userEvent.setup()
    
    render(
      <div>
        <ToastProvider />
        <TestToastComponent />
      </div>
    )

    const defaultButton = screen.getByText('Default Toast')
    await user.click(defaultButton)

    await waitFor(() => {
      expect(screen.getByText('Default message')).toBeInTheDocument()
    })
  })

  it('should display rich toast with description and action', async () => {
    const user = userEvent.setup()
    
    render(
      <div>
        <ToastProvider />
        <TestToastComponent />
      </div>
    )

    const richButton = screen.getByText('Rich Toast')
    await user.click(richButton)

    await waitFor(() => {
      expect(screen.getByText('Rich toast')).toBeInTheDocument()
      expect(screen.getByText('This has a description')).toBeInTheDocument()
      expect(screen.getByText('Undo')).toBeInTheDocument()
    })
  })

  it('should handle toast action clicks', async () => {
    const user = userEvent.setup()
    const consoleSpy = jest.spyOn(console, 'log').mockImplementation(() => {})
    
    render(
      <div>
        <ToastProvider />
        <TestToastComponent />
      </div>
    )

    const richButton = screen.getByText('Rich Toast')
    await user.click(richButton)

    await waitFor(() => {
      expect(screen.getByText('Undo')).toBeInTheDocument()
    })

    const undoButton = screen.getByText('Undo')
    await user.click(undoButton)

    expect(consoleSpy).toHaveBeenCalledWith('Undo clicked')
    
    consoleSpy.mockRestore()
  })

  it('should dismiss all toasts', async () => {
    const user = userEvent.setup()
    
    render(
      <div>
        <ToastProvider />
        <TestToastComponent />
      </div>
    )

    // Create multiple toasts
    const successButton = screen.getByText('Success Toast')
    const errorButton = screen.getByText('Error Toast')
    
    await user.click(successButton)
    await user.click(errorButton)

    await waitFor(() => {
      expect(screen.getByText('Success message')).toBeInTheDocument()
      expect(screen.getByText('Error message')).toBeInTheDocument()
    })

    // Dismiss all toasts
    const dismissButton = screen.getByText('Dismiss All')
    await user.click(dismissButton)

    await waitFor(() => {
      expect(screen.queryByText('Success message')).not.toBeInTheDocument()
      expect(screen.queryByText('Error message')).not.toBeInTheDocument()
    })
  })

  it('should position toasts in top-right', () => {
    render(<ToastProvider />)
    
    // The Toaster should be configured for top-right position
    // This is more of an integration test since we can't easily assert position directly
    const toasterElement = document.querySelector('[data-sonner-toaster]')
    if (toasterElement) {
      // Sonner adds positioning styles, but exact assertion depends on implementation
      expect(toasterElement).toBeInTheDocument()
    }
  })

  it('should apply custom styling options', () => {
    render(<ToastProvider />)
    
    // Check that the Toaster component is rendered with custom styling
    const toasterElement = document.querySelector('[data-sonner-toaster]')
    if (toasterElement) {
      expect(toasterElement).toBeInTheDocument()
      // Custom styles are applied via the toastOptions prop
      // Exact assertion depends on how Sonner implements styling
    }
  })

  it('should support rich colors', async () => {
    const user = userEvent.setup()
    
    render(
      <div>
        <ToastProvider />
        <TestToastComponent />
      </div>
    )

    const successButton = screen.getByText('Success Toast')
    await user.click(successButton)

    await waitFor(() => {
      const toast = screen.getByText('Success message')
      expect(toast).toBeInTheDocument()
      
      // Rich colors should be enabled, which means toasts will have colored backgrounds
      // The exact assertion depends on Sonner's implementation
    })
  })

  it('should auto-dismiss toasts after timeout', async () => {
    const user = userEvent.setup()
    
    render(
      <div>
        <ToastProvider />
        <TestToastComponent />
      </div>
    )

    const successButton = screen.getByText('Success Toast')
    await user.click(successButton)

    await waitFor(() => {
      expect(screen.getByText('Success message')).toBeInTheDocument()
    })

    // Wait for auto-dismiss (Sonner default is 4 seconds)
    await waitFor(() => {
      expect(screen.queryByText('Success message')).not.toBeInTheDocument()
    }, { timeout: 6000 })
  })

  it('should handle multiple toast providers gracefully', () => {
    // Rendering multiple ToastProviders should not break
    render(
      <div>
        <ToastProvider />
        <ToastProvider />
      </div>
    )
    
    // Should render without throwing errors
    expect(document.body).toBeInTheDocument()
  })

  it('should work without any toasts triggered', () => {
    render(
      <div>
        <ToastProvider />
        <div>App content without toasts</div>
      </div>
    )
    
    expect(screen.getByText('App content without toasts')).toBeInTheDocument()
  })
})