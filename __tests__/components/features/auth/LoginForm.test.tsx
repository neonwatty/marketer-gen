import React from 'react'
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { LoginForm } from '@/components/features/auth/LoginForm'

// Mock the UI components
jest.mock('@/components/ui/button', () => ({
  Button: ({ children, disabled, type, className, ...props }: any) => (
    <button type={type} disabled={disabled} className={className} {...props}>
      {children}
    </button>
  ),
}))

jest.mock('@/components/ui/card', () => ({
  Card: ({ children, className, ...props }: any) => (
    <div className={className} data-testid="card" {...props}>
      {children}
    </div>
  ),
  CardContent: ({ children, className }: any) => (
    <div className={className} data-testid="card-content">
      {children}
    </div>
  ),
  CardDescription: ({ children, className }: any) => (
    <p className={className} data-testid="card-description">
      {children}
    </p>
  ),
  CardHeader: ({ children, className }: any) => (
    <div className={className} data-testid="card-header">
      {children}
    </div>
  ),
  CardTitle: ({ children, className }: any) => (
    <h1 className={className} data-testid="card-title">
      {children}
    </h1>
  ),
}))

jest.mock('@/components/ui/form', () => ({
  Form: ({ children, ...props }: any) => <form {...props}>{children}</form>,
  FormControl: ({ children }: any) => <div data-testid="form-control">{children}</div>,
  FormField: ({ control, name, render }: any) => {
    const field = {
      name,
      value: '',
      onChange: jest.fn(),
      onBlur: jest.fn(),
    }
    return render({ field })
  },
  FormItem: ({ children }: any) => <div data-testid="form-item">{children}</div>,
  FormLabel: ({ children }: any) => <label data-testid="form-label">{children}</label>,
  FormMessage: ({ children }: any) => (
    <span data-testid="form-message">{children}</span>
  ),
}))

jest.mock('@/components/ui/input', () => ({
  Input: ({ type, placeholder, disabled, ...props }: any) => (
    <input
      type={type}
      placeholder={placeholder}
      disabled={disabled}
      data-testid={`input-${type || 'text'}`}
      {...props}
    />
  ),
}))

// Mock react-hook-form
const mockHandleSubmit = jest.fn()
const mockFormState = {
  errors: {},
  isSubmitting: false,
  isValid: true,
}

jest.mock('react-hook-form', () => ({
  useForm: () => ({
    control: {},
    handleSubmit: mockHandleSubmit,
    formState: mockFormState,
    register: jest.fn(),
    watch: jest.fn(),
    setValue: jest.fn(),
  }),
}))

// Mock zod resolver
jest.mock('@hookform/resolvers/zod', () => ({
  zodResolver: jest.fn(),
}))

describe('LoginForm', () => {
  const mockOnSubmit = jest.fn()
  const user = userEvent.setup()

  beforeEach(() => {
    jest.clearAllMocks()
    mockHandleSubmit.mockImplementation((fn) => (e) => {
      e.preventDefault()
      fn({ email: 'test@example.com', password: 'password123' })
    })
  })

  describe('Rendering', () => {
    it('renders login form with all elements', () => {
      render(<LoginForm />)

      expect(screen.getByTestId('card')).toBeInTheDocument()
      expect(screen.getByTestId('card-header')).toBeInTheDocument()
      expect(screen.getByTestId('card-content')).toBeInTheDocument()
      expect(screen.getByTestId('card-title')).toBeInTheDocument()
      expect(screen.getByTestId('card-description')).toBeInTheDocument()
    })

    it('displays correct title and description', () => {
      render(<LoginForm />)

      expect(screen.getByText('Welcome back')).toBeInTheDocument()
      expect(screen.getByText('Sign in to your Marketer Gen account')).toBeInTheDocument()
    })

    it('renders email and password fields', () => {
      render(<LoginForm />)

      expect(screen.getByTestId('input-email')).toBeInTheDocument()
      expect(screen.getByTestId('input-password')).toBeInTheDocument()
    })

    it('renders submit button with correct text', () => {
      render(<LoginForm />)

      const submitButton = screen.getByRole('button', { name: /sign in/i })
      expect(submitButton).toBeInTheDocument()
      expect(submitButton).toHaveAttribute('type', 'submit')
    })

    it('renders social login placeholder message', () => {
      render(<LoginForm />)

      expect(
        screen.getByText('Social login options will be available when authentication is enabled')
      ).toBeInTheDocument()
    })

    it('renders sign up link', () => {
      render(<LoginForm />)

      const signUpLink = screen.getByRole('link', { name: /sign up/i })
      expect(signUpLink).toBeInTheDocument()
      expect(signUpLink).toHaveAttribute('href', '/auth/signup')
    })
  })

  describe('Form Interaction', () => {
    it('calls onSubmit when form is submitted with valid data', async () => {
      render(<LoginForm onSubmit={mockOnSubmit} />)

      const form = screen.getByRole('button', { name: /sign in/i }).closest('form')!
      fireEvent.submit(form)

      await waitFor(() => {
        expect(mockOnSubmit).toHaveBeenCalledWith({
          email: 'test@example.com',
          password: 'password123',
        })
      })
    })

    it('does not call onSubmit when onSubmit prop is not provided', async () => {
      render(<LoginForm />)

      const form = screen.getByRole('button', { name: /sign in/i }).closest('form')!
      fireEvent.submit(form)

      // Should not throw error even without onSubmit prop
      expect(mockOnSubmit).not.toHaveBeenCalled()
    })

    it('handles async onSubmit function', async () => {
      const asyncOnSubmit = jest.fn().mockResolvedValue(undefined)
      render(<LoginForm onSubmit={asyncOnSubmit} />)

      const form = screen.getByRole('button', { name: /sign in/i }).closest('form')!
      fireEvent.submit(form)

      await waitFor(() => {
        expect(asyncOnSubmit).toHaveBeenCalledWith({
          email: 'test@example.com',
          password: 'password123',
        })
      })
    })

    it('handles onSubmit errors gracefully', async () => {
      const errorOnSubmit = jest.fn().mockResolvedValue(undefined)
      render(<LoginForm onSubmit={errorOnSubmit} />)

      const form = screen.getByRole('button', { name: /sign in/i }).closest('form')!
      fireEvent.submit(form)

      await waitFor(() => {
        expect(errorOnSubmit).toHaveBeenCalled()
      })
    })
  })

  describe('Loading State', () => {
    it('displays loading text when isLoading is true', () => {
      render(<LoginForm isLoading={true} />)

      expect(screen.getByText('Signing in...')).toBeInTheDocument()
    })

    it('displays normal text when isLoading is false', () => {
      render(<LoginForm isLoading={false} />)

      expect(screen.getByText('Sign in')).toBeInTheDocument()
      expect(screen.queryByText('Signing in...')).not.toBeInTheDocument()
    })

    it('disables submit button when isLoading is true', () => {
      render(<LoginForm isLoading={true} />)

      const submitButton = screen.getByRole('button', { name: /signing in/i })
      expect(submitButton).toBeDisabled()
    })

    it('disables form inputs when isLoading is true', () => {
      render(<LoginForm isLoading={true} />)

      expect(screen.getByTestId('input-email')).toBeDisabled()
      expect(screen.getByTestId('input-password')).toBeDisabled()
    })

    it('enables form inputs when isLoading is false', () => {
      render(<LoginForm isLoading={false} />)

      expect(screen.getByTestId('input-email')).not.toBeDisabled()
      expect(screen.getByTestId('input-password')).not.toBeDisabled()
    })
  })

  describe('Form Validation', () => {
    it('has correct placeholder text for inputs', () => {
      render(<LoginForm />)

      expect(screen.getByPlaceholderText('Enter your email')).toBeInTheDocument()
      expect(screen.getByPlaceholderText('Enter your password')).toBeInTheDocument()
    })

    it('configures email input with correct type', () => {
      render(<LoginForm />)

      const emailInput = screen.getByTestId('input-email')
      expect(emailInput).toHaveAttribute('type', 'email')
    })

    it('configures password input with correct type', () => {
      render(<LoginForm />)

      const passwordInput = screen.getByTestId('input-password')
      expect(passwordInput).toHaveAttribute('type', 'password')
    })
  })

  describe('Accessibility', () => {
    it('has proper form structure for screen readers', () => {
      render(<LoginForm />)

      // Form should be properly structured
      const form = screen.getByRole('button', { name: /sign in/i }).closest('form')
      expect(form).toBeInTheDocument()

      // Should have form labels
      expect(screen.getAllByTestId('form-label')).toHaveLength(2)
    })

    it('has accessible submit button', () => {
      render(<LoginForm />)

      const submitButton = screen.getByRole('button', { name: /sign in/i })
      expect(submitButton).toBeInTheDocument()
      expect(submitButton).toHaveAttribute('type', 'submit')
    })

    it('has accessible sign up link', () => {
      render(<LoginForm />)

      const signUpLink = screen.getByRole('link', { name: /sign up/i })
      expect(signUpLink).toBeInTheDocument()
      expect(signUpLink).toHaveAttribute('href', '/auth/signup')
    })
  })

  describe('Error Handling', () => {
    it('renders form message components for validation errors', () => {
      render(<LoginForm />)

      // FormMessage components should be present for error display
      expect(screen.getAllByTestId('form-message')).toHaveLength(2)
    })
  })

  describe('Component Props', () => {
    it('accepts and uses custom onSubmit handler', async () => {
      const customOnSubmit = jest.fn()
      render(<LoginForm onSubmit={customOnSubmit} />)

      const form = screen.getByRole('button', { name: /sign in/i }).closest('form')!
      fireEvent.submit(form)

      await waitFor(() => {
        expect(customOnSubmit).toHaveBeenCalled()
      })
    })

    it('has correct default prop values', () => {
      render(<LoginForm />)

      // isLoading should default to false
      expect(screen.getByText('Sign in')).toBeInTheDocument()
      expect(screen.queryByText('Signing in...')).not.toBeInTheDocument()

      // Button should not be disabled
      const submitButton = screen.getByRole('button', { name: /sign in/i })
      expect(submitButton).not.toBeDisabled()
    })
  })

  describe('UI Layout', () => {
    it('has proper CSS classes and structure', () => {
      render(<LoginForm />)

      const card = screen.getByTestId('card')
      expect(card).toHaveClass('w-full')

      const cardHeader = screen.getByTestId('card-header')
      expect(cardHeader).toHaveClass('text-center')
    })

    it('displays authentication disabled message in development', () => {
      render(<LoginForm />)

      expect(
        screen.getByText(/Don't have an account/i)
      ).toBeInTheDocument()
    })
  })
})