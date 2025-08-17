import { describe, it, expect, beforeEach, afterEach, jest } from '@jest/globals'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { DuplicateCampaignDialog } from '@/components/features/dashboard/DuplicateCampaignDialog'
import { useDuplicateCampaign } from '@/lib/hooks/use-campaigns'

// Mock the hooks
const mockUseDuplicateCampaign = jest.fn()

jest.mock('@/lib/hooks/use-campaigns', () => ({
  useDuplicateCampaign: mockUseDuplicateCampaign,
}))

const createWrapper = () => {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  })

  return ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={queryClient}>
      {children}
    </QueryClientProvider>
  )
}

describe('DuplicateCampaignDialog', () => {
  const mockMutate = jest.fn()
  const mockCampaign = {
    id: 'campaign-123',
    name: 'Test Campaign',
    purpose: 'Test purpose',
    status: 'DRAFT' as const,
    brandId: 'brand-123',
    userId: 'user-123',
    createdAt: '2023-01-01T00:00:00Z',
    updatedAt: '2023-01-01T00:00:00Z'
  }
  const defaultProps = {
    open: true,
    onOpenChange: jest.fn(),
    onConfirm: jest.fn(),
    isLoading: false
  }

  beforeEach(() => {
    jest.clearAllMocks()
    
    // Set up default mock for useDuplicateCampaign
    mockUseDuplicateCampaign.mockReturnValue({
      mutate: mockMutate,
      isPending: false,
      isError: false,
      error: null,
      isSuccess: false,
      data: undefined
    } as any)
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  it('should render dialog when open', () => {
    render(<DuplicateCampaignDialog {...defaultProps} />, { wrapper: createWrapper() })

    expect(screen.getByRole('heading', { name: /duplicate campaign/i })).toBeInTheDocument()
    expect(screen.getByText(/create a copy of this campaign/i)).toBeInTheDocument()
    expect(screen.getByLabelText(/campaign name/i)).toBeInTheDocument()
  })

  it('should not render dialog when closed', () => {
    render(<DuplicateCampaignDialog {...defaultProps} open={false} />, { wrapper: createWrapper() })

    expect(screen.queryByText(/duplicate campaign/i)).not.toBeInTheDocument()
  })

  it('should have empty form initially', () => {
    render(<DuplicateCampaignDialog {...defaultProps} />, { wrapper: createWrapper() })

    const nameInput = screen.getByLabelText(/campaign name/i)
    expect(nameInput).toHaveValue('')
  })

  it('should handle form submission with valid data', async () => {
    const user = userEvent.setup()
    const mockOnConfirm = jest.fn()
    
    render(
      <DuplicateCampaignDialog {...defaultProps} onConfirm={mockOnConfirm} />, 
      { wrapper: createWrapper() }
    )

    const nameInput = screen.getByLabelText(/campaign name/i)
    await user.type(nameInput, 'My Duplicated Campaign')

    const submitButton = screen.getByRole('button', { name: /duplicate campaign/i })
    await user.click(submitButton)

    expect(mockOnConfirm).toHaveBeenCalledWith('My Duplicated Campaign')
  })

  it('should not call onConfirm when name is empty', async () => {
    const user = userEvent.setup()
    const mockOnConfirm = jest.fn()
    render(<DuplicateCampaignDialog {...defaultProps} onConfirm={mockOnConfirm} />, { wrapper: createWrapper() })

    const nameInput = screen.getByLabelText(/campaign name/i)
    await user.clear(nameInput)

    const submitButton = screen.getByRole('button', { name: /duplicate campaign/i })
    await user.click(submitButton)

    // Should not call onConfirm when name is empty
    expect(mockOnConfirm).not.toHaveBeenCalled()
  })

  it('should accept long names without validation', async () => {
    const user = userEvent.setup()
    const mockOnConfirm = jest.fn()
    render(<DuplicateCampaignDialog {...defaultProps} onConfirm={mockOnConfirm} />, { wrapper: createWrapper() })

    const nameInput = screen.getByLabelText(/campaign name/i)
    await user.clear(nameInput)
    const longName = 'a'.repeat(256) // Longer than 255 characters
    await user.type(nameInput, longName)

    const submitButton = screen.getByRole('button', { name: /duplicate campaign/i })
    await user.click(submitButton)

    // Component doesn't have length validation, so it should call onConfirm
    expect(mockOnConfirm).toHaveBeenCalledWith(longName)
  })

  it('should disable submit button when loading', () => {
    mockUseDuplicateCampaign.mockReturnValue({
      mutate: mockMutate,
      isPending: true,
      isError: false,
      error: null,
      isSuccess: false,
      data: undefined
    } as any)

    render(<DuplicateCampaignDialog {...defaultProps} />, { wrapper: createWrapper() })

    const submitButton = screen.getByRole('button', { name: /duplicate campaign/i })
    expect(submitButton).toBeDisabled()
  })

  it('should show loading state while duplicating', () => {
    mockUseDuplicateCampaign.mockReturnValue({
      mutate: mockMutate,
      isPending: true,
      isError: false,
      error: null,
      isSuccess: false,
      data: undefined
    } as any)

    render(<DuplicateCampaignDialog {...defaultProps} isLoading={true} />, { wrapper: createWrapper() })

    // Check that the submit button is disabled and spinner is shown
    const submitButton = screen.getByRole('button', { name: /duplicate campaign/i })
    expect(submitButton).toBeDisabled()
    
    // Check for loading spinner
    const spinner = document.querySelector('.animate-spin')
    expect(spinner).toBeInTheDocument()
  })

  it('should close dialog on cancel', async () => {
    const user = userEvent.setup()
    const mockOnOpenChange = jest.fn()
    
    render(
      <DuplicateCampaignDialog {...defaultProps} onOpenChange={mockOnOpenChange} />, 
      { wrapper: createWrapper() }
    )

    const cancelButton = screen.getByText(/cancel/i)
    await user.click(cancelButton)

    expect(mockOnOpenChange).toHaveBeenCalledWith(false)
  })

  it('should call onConfirm and clear form on submission', async () => {
    const user = userEvent.setup()
    const mockOnConfirm = jest.fn()
    
    render(
      <DuplicateCampaignDialog {...defaultProps} onConfirm={mockOnConfirm} />, 
      { wrapper: createWrapper() }
    )

    const nameInput = screen.getByLabelText(/campaign name/i)
    await user.type(nameInput, 'My New Campaign')

    const submitButton = screen.getByRole('button', { name: /duplicate campaign/i })
    await user.click(submitButton)

    expect(mockOnConfirm).toHaveBeenCalledWith('My New Campaign')
    
    // Form should be cleared after submission
    expect(nameInput).toHaveValue('')
  })

  it('should handle keyboard shortcuts', async () => {
    const user = userEvent.setup()
    const mockOnOpenChange = jest.fn()
    
    render(
      <DuplicateCampaignDialog {...defaultProps} onOpenChange={mockOnOpenChange} />, 
      { wrapper: createWrapper() }
    )

    // Press Escape to close
    await user.keyboard('{Escape}')

    expect(mockOnOpenChange).toHaveBeenCalledWith(false)
  })
})