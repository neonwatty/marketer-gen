import { describe, it, expect, vi, beforeEach } from 'vitest'
import { waitFor } from '@testing-library/react'
import { z } from 'zod'
import { renderWithForm, render } from '@/test/test-utils'
import { FormProvider, useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import userEvent from '@testing-library/user-event'
import { ReactElement } from 'react'
import { 
  TextField, 
  PasswordField, 
  TextareaField, 
  SelectField, 
  FormActions 
} from '@/components/forms/FormFields'

// Test schema for form field components
const formFieldTestSchema = z.object({
  textField: z.string().min(1, 'Text field is required'),
  emailField: z.string().email('Please enter a valid email'),
  urlField: z.string().url('Please enter a valid URL'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  confirmPassword: z.string(),
  description: z.string().min(10, 'Description must be at least 10 characters'),
  category: z.enum(['option1', 'option2', 'option3'], { message: 'Please select a category' }),
  status: z.enum(['active', 'inactive', 'pending'], { message: 'Please select a status' }),
}).refine(data => data.password === data.confirmPassword, {
  message: "Passwords don't match",
  path: ['confirmPassword'],
})

type FormFieldTestData = z.infer<typeof formFieldTestSchema>

const selectOptions = [
  { value: 'option1', label: 'Option 1' },
  { value: 'option2', label: 'Option 2' },
  { value: 'option3', label: 'Option 3' },
]

const statusOptions = [
  { value: 'active', label: 'Active' },
  { value: 'inactive', label: 'Inactive' },
  { value: 'pending', label: 'Pending', disabled: true },
]

describe('Form Fields Component Tests', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('TextField Component', () => {
    it('renders basic text field with label and placeholder', () => {
      const { container, getByLabelText } = renderWithForm<FormFieldTestData>(
        <TextField 
          name="textField"
          label="Text Input"
          placeholder="Enter some text"
        />,
        { schema: formFieldTestSchema }
      )

      const input = getByLabelText('Text Input')
      expect(input).toBeInTheDocument()
      expect(input).toHaveAttribute('type', 'text')
      expect(input).toHaveAttribute('placeholder', 'Enter some text')
      expect(input).toHaveAttribute('name', 'textField')
    })

    it('renders email field with correct type', () => {
      const { getByLabelText } = renderWithForm<FormFieldTestData>(
        <TextField 
          name="emailField"
          label="Email Address"
          type="email"
          placeholder="Enter your email"
        />,
        { schema: formFieldTestSchema }
      )

      const input = getByLabelText('Email Address')
      expect(input).toHaveAttribute('type', 'email')
      expect(input).toHaveAttribute('placeholder', 'Enter your email')
    })

    it('renders URL field with correct type', () => {
      const { getByLabelText } = renderWithForm<FormFieldTestData>(
        <TextField 
          name="urlField"
          label="Website URL"
          type="url"
          placeholder="https://example.com"
        />,
        { schema: formFieldTestSchema }
      )

      const input = getByLabelText('Website URL')
      expect(input).toHaveAttribute('type', 'url')
      expect(input).toHaveAttribute('placeholder', 'https://example.com')
    })

    it('shows required indicator when field is required', () => {
      const { getByText } = renderWithForm<FormFieldTestData>(
        <TextField 
          name="textField"
          label="Required Field"
          required
        />,
        { schema: formFieldTestSchema }
      )

      // Check for required asterisk
      expect(getByText('*')).toBeInTheDocument()
      expect(getByText('*')).toHaveClass('text-destructive')
    })

    it('accepts user input and updates form state', async () => {
      const { user, getByLabelText } = renderWithForm<FormFieldTestData>(
        <TextField 
          name="textField"
          label="Text Input"
        />,
        { schema: formFieldTestSchema }
      )

      const input = getByLabelText('Text Input')
      await user.type(input, 'Hello World')

      expect(input).toHaveValue('Hello World')
    })

    it('handles disabled state correctly', () => {
      const { getByLabelText } = renderWithForm<FormFieldTestData>(
        <TextField 
          name="textField"
          label="Disabled Input"
          disabled
        />,
        { schema: formFieldTestSchema }
      )

      const input = getByLabelText('Disabled Input')
      expect(input).toBeDisabled()
    })

    it('displays description text when provided', () => {
      const { getByText } = renderWithForm<FormFieldTestData>(
        <TextField 
          name="textField"
          label="Text Input"
          description="This is a helpful description"
        />,
        { schema: formFieldTestSchema }
      )

      expect(getByText('This is a helpful description')).toBeInTheDocument()
    })

    it('shows validation error messages', async () => {
      const mockSubmit = vi.fn()
      const { user, getByTestId } = renderWithForm<FormFieldTestData>(
        <>
          <TextField name="textField" label="Required Text" required />
          <button type="submit" data-testid="submit-btn">Submit</button>
        </>,
        { schema: formFieldTestSchema, onSubmit: mockSubmit }
      )

      const submitButton = getByTestId('submit-btn')
      await user.click(submitButton)

      await waitFor(() => {
        const errorMessage = document.querySelector('[data-slot="form-message"]')
        expect(errorMessage).toBeInTheDocument()
        expect(errorMessage).toHaveTextContent(/Text field is required|expected string.*received undefined/)
      })
      expect(mockSubmit).not.toHaveBeenCalled()
    })
  })

  describe('PasswordField Component', () => {
    it('renders password field with default label', () => {
      const { container, getByText } = renderWithForm<FormFieldTestData>(
        <PasswordField name="password" />,
        { schema: formFieldTestSchema }
      )

      // Check label exists
      expect(getByText('Password')).toBeInTheDocument()
      
      // Find input by name attribute since FormControl wrapper affects label association
      const input = container.querySelector('input[name="password"]')
      expect(input).toBeInTheDocument()
      expect(input).toHaveAttribute('type', 'password')
      expect(input).toHaveAttribute('placeholder', 'Enter your password')
    })

    it('renders password field with custom label and placeholder', () => {
      const { container, getByText } = renderWithForm<FormFieldTestData>(
        <PasswordField 
          name="password"
          label="Custom Password"
          placeholder="Type your password"
        />,
        { schema: formFieldTestSchema }
      )

      expect(getByText('Custom Password')).toBeInTheDocument()
      
      const input = container.querySelector('input[name="password"]')
      expect(input).toHaveAttribute('placeholder', 'Type your password')
    })

    it('toggles password visibility when eye icon is clicked', async () => {
      const { user, container, getByRole } = renderWithForm<FormFieldTestData>(
        <PasswordField name="password" showPasswordToggle />,
        { schema: formFieldTestSchema }
      )

      const input = container.querySelector('input[name="password"]')
      const toggleButton = getByRole('button', { name: /show password/i })

      // Initially password type
      expect(input).toHaveAttribute('type', 'password')

      // Click to show password
      await user.click(toggleButton)
      expect(input).toHaveAttribute('type', 'text')

      // Click to hide password again
      await user.click(toggleButton)
      expect(input).toHaveAttribute('type', 'password')
    })

    it('can disable password toggle feature', () => {
      const { queryByRole } = renderWithForm<FormFieldTestData>(
        <PasswordField name="password" showPasswordToggle={false} />,
        { schema: formFieldTestSchema }
      )

      // Toggle button should not exist
      expect(queryByRole('button', { name: /show password/i })).not.toBeInTheDocument()
    })

    it('disables toggle button when field is disabled', () => {
      const { getByRole } = renderWithForm<FormFieldTestData>(
        <PasswordField name="password" disabled />,
        { schema: formFieldTestSchema }
      )

      const toggleButton = getByRole('button', { name: /show password/i })
      expect(toggleButton).toBeDisabled()
    })

    it('validates password requirements', async () => {
      const mockSubmit = vi.fn()
      const { user, container, getByTestId } = renderWithForm<FormFieldTestData>(
        <>
          <PasswordField name="password" label="Password" />
          <button type="submit" data-testid="submit-btn">Submit</button>
        </>,
        { schema: formFieldTestSchema, onSubmit: mockSubmit }
      )

      const input = container.querySelector('input[name="password"]')
      await user.type(input as HTMLInputElement, 'weak')

      const submitButton = getByTestId('submit-btn')
      await user.click(submitButton)

      await waitFor(() => {
        const errorMessage = document.querySelector('[data-slot="form-message"]')
        expect(errorMessage).toBeInTheDocument()
        expect(errorMessage).toHaveTextContent(/Password must be at least 8 characters/)
      })
    })
  })

  describe('TextareaField Component', () => {
    it('renders textarea with label and placeholder', () => {
      const { getByLabelText } = renderWithForm<FormFieldTestData>(
        <TextareaField 
          name="description"
          label="Description"
          placeholder="Enter description"
        />,
        { schema: formFieldTestSchema }
      )

      const textarea = getByLabelText('Description')
      expect(textarea).toBeInTheDocument()
      expect(textarea.tagName).toBe('TEXTAREA')
      expect(textarea).toHaveAttribute('placeholder', 'Enter description')
    })

    it('applies custom rows attribute', () => {
      const { getByLabelText } = renderWithForm<FormFieldTestData>(
        <TextareaField 
          name="description"
          label="Description"
          rows={5}
        />,
        { schema: formFieldTestSchema }
      )

      const textarea = getByLabelText('Description')
      expect(textarea).toHaveAttribute('rows', '5')
    })

    it('has resize-none class by default', () => {
      const { getByLabelText } = renderWithForm<FormFieldTestData>(
        <TextareaField 
          name="description"
          label="Description"
        />,
        { schema: formFieldTestSchema }
      )

      const textarea = getByLabelText('Description')
      expect(textarea).toHaveClass('resize-none')
    })

    it('accepts multi-line text input', async () => {
      const { user, getByLabelText } = renderWithForm<FormFieldTestData>(
        <TextareaField name="description" label="Description" />,
        { schema: formFieldTestSchema }
      )

      const textarea = getByLabelText('Description')
      const multilineText = `This is line one
This is line two
This is line three`

      await user.type(textarea, multilineText)
      expect(textarea).toHaveValue(multilineText)
    })

    it('validates minimum length requirement', async () => {
      const mockSubmit = vi.fn()
      const { user, getByLabelText, getByTestId } = renderWithForm<FormFieldTestData>(
        <>
          <TextareaField name="description" label="Description" />
          <button type="submit" data-testid="submit-btn">Submit</button>
        </>,
        { schema: formFieldTestSchema, onSubmit: mockSubmit }
      )

      const textarea = getByLabelText('Description')
      await user.type(textarea, 'short') // Less than 10 characters

      const submitButton = getByTestId('submit-btn')
      await user.click(submitButton)

      await waitFor(() => {
        const errorMessage = document.querySelector('[data-slot="form-message"]')
        expect(errorMessage).toBeInTheDocument()
        expect(errorMessage).toHaveTextContent(/Description must be at least 10 characters/)
      })
    })
  })

  describe('SelectField Component', () => {
    it('renders select field with label and placeholder', () => {
      const { getByText, getByRole } = renderWithForm<FormFieldTestData>(
        <SelectField 
          name="category"
          label="Category"
          placeholder="Choose category"
          options={selectOptions}
        />,
        { schema: formFieldTestSchema }
      )

      expect(getByText('Category')).toBeInTheDocument()
      
      const trigger = getByRole('combobox')
      expect(trigger).toBeInTheDocument()
      expect(getByText('Choose category')).toBeInTheDocument()
    })

    it('renders with correct trigger state', () => {
      const { getByRole, getByText } = renderWithForm<FormFieldTestData>(
        <SelectField 
          name="category"
          label="Category"
          options={selectOptions}
        />,
        { schema: formFieldTestSchema }
      )

      const trigger = getByRole('combobox')
      expect(trigger).toBeInTheDocument()
      expect(trigger).toHaveAttribute('aria-expanded', 'false')
    })

    it('shows placeholder text initially', () => {
      const { getByText } = renderWithForm<FormFieldTestData>(
        <SelectField 
          name="category"
          label="Category"
          placeholder="Choose category"
          options={selectOptions}
        />,
        { schema: formFieldTestSchema }
      )

      // Check placeholder is visible
      expect(getByText('Choose category')).toBeInTheDocument()
    })

    it('is clickable and interactive', async () => {
      const { user, getByRole } = renderWithForm<FormFieldTestData>(
        <SelectField 
          name="category"
          label="Category"
          options={selectOptions}
        />,
        { schema: formFieldTestSchema }
      )

      const trigger = getByRole('combobox')
      
      // Should be clickable without throwing an error
      await user.click(trigger)
      
      // Verify it's still a combobox after interaction
      expect(trigger).toBeInTheDocument()
      expect(trigger).toHaveAttribute('role', 'combobox')
    })

    it('can be disabled entirely', () => {
      const { getByRole } = renderWithForm<FormFieldTestData>(
        <SelectField 
          name="category"
          label="Category"
          options={selectOptions}
          disabled
        />,
        { schema: formFieldTestSchema }
      )

      // Check for disabled combobox - radix-ui sets disabled on the trigger button
      const trigger = getByRole('combobox')
      expect(trigger).toBeDisabled()
    })

    it('validates selection requirement', async () => {
      const mockSubmit = vi.fn()
      const { user, getByTestId } = renderWithForm<FormFieldTestData>(
        <>
          <SelectField 
            name="category" 
            label="Category" 
            options={selectOptions} 
            required
          />
          <button type="submit" data-testid="submit-btn">Submit</button>
        </>,
        { schema: formFieldTestSchema, onSubmit: mockSubmit }
      )

      const submitButton = getByTestId('submit-btn')
      await user.click(submitButton)

      await waitFor(() => {
        const errorMessage = document.querySelector('[data-slot="form-message"]')
        expect(errorMessage).toBeInTheDocument()
        expect(errorMessage).toHaveTextContent(/Please select a category/)
      })
    })
  })

  describe('FormActions Component', () => {
    // Custom form wrapper for FormActions tests to avoid duplicate submit buttons
    const FormActionsWrapper = ({ children }: { children: React.ReactNode }) => {
      const formMethods = useForm<FormFieldTestData>({
        resolver: zodResolver(formFieldTestSchema),
      })

      return (
        <FormProvider {...formMethods}>
          <form onSubmit={formMethods.handleSubmit(() => {})}>
            {children}
          </form>
        </FormProvider>
      )
    }

    const renderFormActions = (ui: ReactElement) => {
      return render(
        <FormActionsWrapper>{ui}</FormActionsWrapper>
      )
    }

    it('renders default submit button', () => {
      const { getByRole } = renderFormActions(<FormActions />)

      const submitButton = getByRole('button', { name: 'Submit' })
      expect(submitButton).toBeInTheDocument()
      expect(submitButton).toHaveAttribute('type', 'submit')
    })

    it('renders custom submit button text', () => {
      const { getByRole } = renderFormActions(
        <FormActions submitText="Create Account" />
      )

      expect(getByRole('button', { name: 'Create Account' })).toBeInTheDocument()
    })

    it('shows cancel button when enabled', () => {
      const mockCancel = vi.fn()
      const { getByRole } = renderFormActions(
        <FormActions 
          showCancel 
          onCancel={mockCancel}
          cancelText="Go Back"
        />
      )

      const cancelButton = getByRole('button', { name: 'Go Back' })
      expect(cancelButton).toBeInTheDocument()
      expect(cancelButton).toHaveAttribute('type', 'button')
    })

    it('calls onCancel when cancel button is clicked', async () => {
      const mockCancel = vi.fn()
      const { getByRole } = renderFormActions(
        <FormActions showCancel onCancel={mockCancel} />
      )

      const cancelButton = getByRole('button', { name: 'Cancel' })
      await userEvent.setup().click(cancelButton)

      expect(mockCancel).toHaveBeenCalledTimes(1)
    })

    it('shows submitting state', () => {
      const { getByRole } = renderFormActions(
        <FormActions isSubmitting />
      )

      const submitButton = getByRole('button', { name: 'Submitting...' })
      expect(submitButton).toBeInTheDocument()
      expect(submitButton).toBeDisabled()
    })

    it('disables submit button when submitDisabled is true', () => {
      const { getByRole } = renderFormActions(
        <FormActions submitDisabled />
      )

      const submitButton = getByRole('button', { name: 'Submit' })
      expect(submitButton).toBeDisabled()
    })

    it('disables all buttons during submission', () => {
      const mockCancel = vi.fn()
      const { getByRole } = renderFormActions(
        <FormActions 
          isSubmitting
          showCancel 
          onCancel={mockCancel}
        />
      )

      const submitButton = getByRole('button', { name: 'Submitting...' })
      const cancelButton = getByRole('button', { name: 'Cancel' })

      expect(submitButton).toBeDisabled()
      expect(cancelButton).toBeDisabled()
    })

    it('renders custom children instead of default buttons', () => {
      const { getByRole, queryByRole } = renderFormActions(
        <FormActions>
          <button type="button" data-testid="custom-btn">Custom Action</button>
          <button type="submit" data-testid="custom-submit">Custom Submit</button>
        </FormActions>
      )

      expect(getByRole('button', { name: 'Custom Action' })).toBeInTheDocument()
      expect(getByRole('button', { name: 'Custom Submit' })).toBeInTheDocument()
      
      // Default Submit button should not exist when custom children are provided
      expect(queryByRole('button', { name: 'Submit' })).not.toBeInTheDocument()
    })

    it('applies custom className', () => {
      const { container } = renderFormActions(
        <FormActions className="custom-actions-class" />
      )

      const actionsContainer = container.querySelector('.custom-actions-class')
      expect(actionsContainer).toBeInTheDocument()
      expect(actionsContainer).toHaveClass('flex', 'gap-3')
    })
  })

  describe('Form Field Interactions and Integration', () => {
    it('handles complex form with multiple field types', async () => {
      const mockSubmit = vi.fn()
      const { user, getByLabelText, container, getByTestId } = renderWithForm<FormFieldTestData>(
        <>
          <TextField name="textField" label="Text Field" />
          <TextField name="emailField" label="Email" type="email" />
          <TextField name="urlField" label="URL" type="url" />
          <PasswordField name="password" label="Password" />
          <PasswordField name="confirmPassword" label="Confirm Password" />
          <TextareaField name="description" label="Description" />
          <SelectField name="status" label="Status" options={statusOptions} />
          <button type="submit" data-testid="submit-btn">Submit</button>
        </>,
        { 
          schema: formFieldTestSchema, 
          onSubmit: mockSubmit,
          defaultValues: {
            category: 'option1', // Pre-select category to avoid complex dropdown interaction
            status: 'active' // Pre-select status to avoid complex dropdown interaction
          }
        }
      )

      // Fill out all fields
      await user.type(getByLabelText('Text Field'), 'Sample text')
      await user.type(getByLabelText('Email'), 'test@example.com')
      await user.type(getByLabelText('URL'), 'https://example.com')
      await user.type(container.querySelector('input[name="password"]') as HTMLInputElement, 'Password123!')
      await user.type(container.querySelector('input[name="confirmPassword"]') as HTMLInputElement, 'Password123!')
      await user.type(getByLabelText('Description'), 'This is a detailed description')

      // Submit form (category is pre-selected)
      const submitButton = getByTestId('submit-btn')
      await user.click(submitButton)

      await waitFor(() => {
        expect(mockSubmit).toHaveBeenCalled()
        const callArgs = mockSubmit.mock.calls[0][0] // Get first argument (form data)
        expect(callArgs).toEqual({
          textField: 'Sample text',
          emailField: 'test@example.com',
          urlField: 'https://example.com',
          password: 'Password123!',
          confirmPassword: 'Password123!',
          description: 'This is a detailed description',
          category: 'option1',
          status: 'active',
        })
      })
    })

    it('prevents submission with validation errors across multiple fields', async () => {
      const mockSubmit = vi.fn()
      const { user, getByLabelText, getByTestId } = renderWithForm<FormFieldTestData>(
        <>
          <TextField name="textField" label="Text Field" required />
          <TextField name="emailField" label="Email" type="email" required />
        </>,
        { 
          schema: formFieldTestSchema, 
          onSubmit: mockSubmit,
          skipAutoDefaults: true // Skip auto defaults to ensure clean test
        }
      )

      // Submit form without filling any fields - should show multiple validation errors
      const submitButton = getByTestId('submit-button')
      await user.click(submitButton)

      await waitFor(() => {
        // Should show validation errors for missing required fields
        const errorMessages = document.querySelectorAll('[data-slot="form-message"]')
        expect(errorMessages.length).toBeGreaterThan(1)
      })

      expect(mockSubmit).not.toHaveBeenCalled()
    })
  })
})