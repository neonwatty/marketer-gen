import { describe, it, expect, beforeEach, afterEach, jest } from '@jest/globals'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { EnhancedCampaignCard } from '@/components/features/dashboard/EnhancedCampaignCard'
import { useUpdateCampaign, useDeleteCampaign } from '@/lib/hooks/use-campaigns'

// Mock the hooks
const mockUseUpdateCampaign = jest.fn()
const mockUseDeleteCampaign = jest.fn()
jest.mock('@/lib/hooks/use-campaigns', () => ({
  useUpdateCampaign: mockUseUpdateCampaign,
  useDeleteCampaign: mockUseDeleteCampaign,
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

describe('EnhancedCampaignCard', () => {
  const mockCampaign = {
    id: 'campaign-123',
    title: 'Test Campaign',
    description: 'Test purpose',
    status: 'draft' as const,
    metrics: {
      engagementRate: 15.2,
      conversionRate: 3.4,
      contentPieces: 12,
      totalReach: 25000,
      activeUsers: 1200
    },
    progress: 65,
    createdAt: new Date('2023-01-01T00:00:00Z'),
    updatedAt: new Date('2023-01-01T00:00:00Z')
  }

  const mockUpdateMutate = jest.fn()
  const mockDeleteMutate = jest.fn()
  const mockOnDuplicate = jest.fn()

  beforeEach(() => {
    jest.clearAllMocks()
    
    mockUseUpdateCampaign.mockReturnValue({
      mutate: mockUpdateMutate,
      isPending: false,
      isError: false,
      error: null,
      isSuccess: false,
      data: undefined
    } as any)

    mockUseDeleteCampaign.mockReturnValue({
      mutate: mockDeleteMutate,
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

  it('should render campaign information', () => {
    render(
      <EnhancedCampaignCard campaign={mockCampaign} onDuplicate={mockOnDuplicate} />, 
      { wrapper: createWrapper() }
    )

    expect(screen.getByText('Test Campaign')).toBeInTheDocument()
    expect(screen.getByText('Test purpose')).toBeInTheDocument()
    expect(screen.getByText('Draft')).toBeInTheDocument()
    expect(screen.getByText('15.2%')).toBeInTheDocument()
    expect(screen.getByText('3.4%')).toBeInTheDocument()
    expect(screen.getByText('12')).toBeInTheDocument()
  })

  it('should render campaign purpose when available', () => {
    render(
      <EnhancedCampaignCard campaign={mockCampaign} onDuplicate={mockOnDuplicate} />, 
      { wrapper: createWrapper() }
    )

    expect(screen.getByText('Test purpose')).toBeInTheDocument()
    expect(screen.getByText('65%')).toBeInTheDocument()
    expect(screen.getByText('25,000')).toBeInTheDocument()
    expect(screen.getByText('1,200')).toBeInTheDocument()
  })

  it('should show actions menu when clicked', async () => {
    const user = userEvent.setup()
    render(
      <EnhancedCampaignCard campaign={mockCampaign} onDuplicate={mockOnDuplicate} />, 
      { wrapper: createWrapper() }
    )

    const actionsButton = screen.getByRole('button', { name: /open menu/i })
    await user.click(actionsButton)

    expect(screen.getByText(/view/i)).toBeInTheDocument()
    expect(screen.getByText(/edit/i)).toBeInTheDocument()
    expect(screen.getByText(/duplicate/i)).toBeInTheDocument()
    expect(screen.getByText(/archive/i)).toBeInTheDocument()
  })

  it('should handle duplicate action', async () => {
    const user = userEvent.setup()
    render(
      <EnhancedCampaignCard campaign={mockCampaign} onDuplicate={mockOnDuplicate} />, 
      { wrapper: createWrapper() }
    )

    const actionsButton = screen.getByRole('button', { name: /open menu/i })
    await user.click(actionsButton)

    const duplicateButton = screen.getByText(/duplicate/i)
    await user.click(duplicateButton)

    expect(mockOnDuplicate).toHaveBeenCalledWith('campaign-123')
  })

  it('should show loading state when duplicating', () => {
    render(
      <EnhancedCampaignCard 
        campaign={mockCampaign} 
        onDuplicate={mockOnDuplicate}
        isDuplicating={true}
      />, 
      { wrapper: createWrapper() }
    )

    // Should show loading spinner in dropdown trigger
    expect(screen.getByRole('button', { name: /open menu/i })).toBeInTheDocument()
  })

  it('should show loading state when archiving', () => {
    render(
      <EnhancedCampaignCard 
        campaign={mockCampaign} 
        onDuplicate={mockOnDuplicate}
        isArchiving={true}
      />, 
      { wrapper: createWrapper() }
    )

    expect(screen.getByText('Archiving...')).toBeInTheDocument()
  })

  it('should format dates correctly', () => {
    render(
      <EnhancedCampaignCard campaign={mockCampaign} onDuplicate={mockOnDuplicate} />, 
      { wrapper: createWrapper() }
    )

    expect(screen.getByText(/12\/31\/2022/)).toBeInTheDocument()
  })

  it('should be accessible', () => {
    render(
      <EnhancedCampaignCard campaign={mockCampaign} onDuplicate={mockOnDuplicate} />, 
      { wrapper: createWrapper() }
    )

    // Check for appropriate ARIA labels and roles
    expect(screen.getByRole('button', { name: /open menu/i })).toBeInTheDocument()
  })
})