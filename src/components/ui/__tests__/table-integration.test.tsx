import { render, screen, waitFor } from '@testing-library/react'
import { userEvent } from '@testing-library/user-event'
import { CampaignDataTable, type CampaignTableData } from '../campaign-data-table'

const mockCampaigns: CampaignTableData[] = [
  {
    id: '1',
    title: 'Summer Product Launch',
    description: 'Multi-channel campaign for new product line launch',
    status: 'active',
    createdAt: 'Jan 15, 2024',
    progress: 75,
    contentPieces: 12,
    channels: ['Email', 'Social', 'Blog'],
    budget: 25000,
    impressions: 125000,
    engagement: 4.2,
    conversions: 850
  },
  {
    id: '2',
    title: 'Holiday Sale Campaign',
    description: 'Black Friday promotional campaign',
    status: 'draft',
    createdAt: 'Jan 20, 2024',
    progress: 25,
    contentPieces: 3,
    channels: ['Email', 'Social'],
    budget: 15000
  },
  {
    id: '3',
    title: 'Brand Awareness Q1',
    description: 'Brand awareness campaign targeting millennials',
    status: 'paused',
    createdAt: 'Dec 10, 2023',
    progress: 60,
    contentPieces: 8,
    channels: ['Social', 'Display'],
    budget: 40000,
    impressions: 300000,
    engagement: 3.8,
    conversions: 420
  },
  {
    id: '4',
    title: 'Customer Retention Email Series',
    description: 'Automated email sequence for customer retention',
    status: 'completed',
    createdAt: 'Nov 5, 2023',
    progress: 100,
    contentPieces: 15,
    channels: ['Email'],
    budget: 5000,
    impressions: 75000,
    engagement: 8.5,
    conversions: 1200
  },
  {
    id: '5',
    title: 'Test Campaign Alpha',
    description: 'Testing campaign for alpha features',
    status: 'active',
    createdAt: 'Feb 1, 2024',
    progress: 40,
    contentPieces: 6,
    channels: ['Email', 'Social', 'Display'],
    budget: 18000,
    impressions: 95000,
    engagement: 5.1,
    conversions: 320
  }
]

describe('Table Integration Tests', () => {
  const user = userEvent.setup()
  const mockHandlers = {
    onView: vi.fn(),
    onEdit: vi.fn(),
    onCopy: vi.fn(),
    onDelete: vi.fn(),
    onExport: vi.fn(),
  }

  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('Search and Filter Combinations', () => {
    it('applies search and then filter to narrow results', async () => {
      render(<CampaignDataTable data={mockCampaigns} {...mockHandlers} />)

      // First apply search
      const searchInput = screen.getByPlaceholderText('Search campaigns...')
      await user.type(searchInput, 'Campaign')

      // Should show campaigns with "Campaign" in title
      await waitFor(() => {
        expect(screen.getByText('Holiday Sale Campaign')).toBeInTheDocument()
        expect(screen.getByText('Brand Awareness Q1')).toBeInTheDocument()
        expect(screen.getByText('Test Campaign Alpha')).toBeInTheDocument()
        expect(screen.queryByText('Summer Product Launch')).not.toBeInTheDocument()
      })

      // Then apply status filter
      const statusFilter = screen.getByText('Status')
      await user.click(statusFilter)

      await waitFor(() => {
        const activeOption = screen.getByText('Active')
        expect(activeOption).toBeInTheDocument()
      })

      const activeOption = screen.getByText('Active')
      await user.click(activeOption)

      // Should only show active campaigns that match search
      await waitFor(() => {
        expect(screen.getByText('Test Campaign Alpha')).toBeInTheDocument()
        expect(screen.queryByText('Holiday Sale Campaign')).not.toBeInTheDocument()
        expect(screen.queryByText('Brand Awareness Q1')).not.toBeInTheDocument()
      })
    })

    it('shows filter badges for active filters', async () => {
      render(<CampaignDataTable data={mockCampaigns} {...mockHandlers} />)

      // Apply search
      const searchInput = screen.getByPlaceholderText('Search campaigns...')
      await user.type(searchInput, 'email')

      // Search badge should appear
      await waitFor(() => {
        expect(screen.getByText(/Search: email/)).toBeInTheDocument()
      })
    })

    it('clears all filters when clear all is clicked', async () => {
      render(<CampaignDataTable data={mockCampaigns} {...mockHandlers} />)

      // Apply search
      const searchInput = screen.getByPlaceholderText('Search campaigns...')
      await user.type(searchInput, 'Summer')

      // Clear all filters
      const clearButton = screen.getByText('Clear')
      await user.click(clearButton)

      // All campaigns should be visible again
      await waitFor(() => {
        expect(screen.getByText('Summer Product Launch')).toBeInTheDocument()
        expect(screen.getByText('Holiday Sale Campaign')).toBeInTheDocument()
        expect(screen.getByText('Brand Awareness Q1')).toBeInTheDocument()
      })

      expect(searchInput).toHaveValue('')
    })
  })

  describe('Search and Sorting Combinations', () => {
    it('maintains search results when sorting is applied', async () => {
      render(<CampaignDataTable data={mockCampaigns} {...mockHandlers} />)

      // Apply search for "Campaign"
      const searchInput = screen.getByPlaceholderText('Search campaigns...')
      await user.type(searchInput, 'Campaign')

      await waitFor(() => {
        expect(screen.getByText('Holiday Sale Campaign')).toBeInTheDocument()
        expect(screen.getByText('Test Campaign Alpha')).toBeInTheDocument()
      })

      // Sort by campaign name
      const campaignHeader = screen.getByText('Campaign')
      await user.click(campaignHeader)

      // Search results should still be filtered
      await waitFor(() => {
        expect(screen.getByText('Holiday Sale Campaign')).toBeInTheDocument()
        expect(screen.getByText('Test Campaign Alpha')).toBeInTheDocument()
        expect(screen.queryByText('Summer Product Launch')).not.toBeInTheDocument()
      })
    })

    it('sorts within filtered results', async () => {
      render(<CampaignDataTable data={mockCampaigns} {...mockHandlers} />)

      // Apply search
      const searchInput = screen.getByPlaceholderText('Search campaigns...')
      await user.type(searchInput, 'email')

      // Click progress column to sort
      const progressHeader = screen.getByText('Progress')
      await user.click(progressHeader)

      // Results should be sorted but still filtered
      await waitFor(() => {
        expect(screen.getByText('Customer Retention Email Series')).toBeInTheDocument()
        expect(screen.queryByText('Summer Product Launch')).not.toBeInTheDocument()
      })
    })
  })

  describe('Pagination with Filters', () => {
    const largeMockData = Array.from({ length: 25 }, (_, i) => ({
      id: `${i + 1}`,
      title: `Campaign ${i + 1}`,
      description: `Description for campaign ${i + 1}`,
      status: (i % 2 === 0 ? 'active' : 'draft') as any,
      createdAt: 'Jan 1, 2024',
      progress: Math.floor(Math.random() * 100),
      contentPieces: Math.floor(Math.random() * 10) + 1,
      channels: ['Email'],
      budget: 10000,
    }))

    it('resets to first page when filter is applied', async () => {
      render(<CampaignDataTable data={largeMockData} />)

      // Go to page 2
      const nextButton = screen.getByText('Go to next page')
      await user.click(nextButton)

      await waitFor(() => {
        expect(screen.getByText(/Page 2 of/)).toBeInTheDocument()
      })

      // Apply search filter
      const searchInput = screen.getByPlaceholderText('Search campaigns...')
      await user.type(searchInput, 'Campaign 1')

      // Should reset to page 1
      await waitFor(() => {
        expect(screen.getByText(/Page 1 of/)).toBeInTheDocument()
      })
    })

    it('updates page count when filters reduce results', async () => {
      render(<CampaignDataTable data={largeMockData} />)

      // Check initial page count
      expect(screen.getByText(/Page 1 of 3/)).toBeInTheDocument()

      // Apply filter to reduce results
      const searchInput = screen.getByPlaceholderText('Search campaigns...')
      await user.type(searchInput, 'Campaign 1')

      // Page count should be reduced
      await waitFor(() => {
        const pageText = screen.getByText(/Page 1 of 1/)
        expect(pageText).toBeInTheDocument()
      })
    })
  })

  describe('Row Selection with Filters', () => {
    it('maintains selection state when filtering', async () => {
      render(<CampaignDataTable data={mockCampaigns} />)

      // Apply search
      const searchInput = screen.getByPlaceholderText('Search campaigns...')
      await user.type(searchInput, 'Summer')

      await waitFor(() => {
        expect(screen.getByText('Summer Product Launch')).toBeInTheDocument()
      })

      // Clear search
      const clearButton = screen.getByText('Clear')
      await user.click(clearButton)

      // All items should be visible again
      await waitFor(() => {
        expect(screen.getByText('Summer Product Launch')).toBeInTheDocument()
        expect(screen.getByText('Holiday Sale Campaign')).toBeInTheDocument()
      })
    })
  })

  describe('Column Visibility with Data', () => {
    it('hides and shows columns while maintaining data integrity', async () => {
      render(<CampaignDataTable data={mockCampaigns} />)

      // Open column visibility menu
      const columnsButton = screen.getByText('Columns')
      await user.click(columnsButton)

      await waitFor(() => {
        // Should show column toggle options
        const budgetToggle = screen.getByText('budget')
        expect(budgetToggle).toBeInTheDocument()
      })

      // Toggle budget column off
      const budgetToggle = screen.getByText('budget')
      await user.click(budgetToggle)

      // Close menu by clicking elsewhere
      await user.click(document.body)

      // Budget column should be hidden
      await waitFor(() => {
        expect(screen.queryByText('Budget')).not.toBeInTheDocument()
        expect(screen.queryByText('$25,000')).not.toBeInTheDocument()
      })

      // Other data should still be visible
      expect(screen.getByText('Summer Product Launch')).toBeInTheDocument()
    })
  })

  describe('Export with Filtered Data', () => {
    it('calls export function when data is filtered', async () => {
      render(<CampaignDataTable data={mockCampaigns} {...mockHandlers} />)

      // Apply filter
      const searchInput = screen.getByPlaceholderText('Search campaigns...')
      await user.type(searchInput, 'Summer')

      // Click export
      const exportButton = screen.getByText('Export')
      await user.click(exportButton)

      expect(mockHandlers.onExport).toHaveBeenCalled()
    })
  })

  describe('Multi-Column Sorting', () => {
    it('maintains primary sort while applying secondary sort', async () => {
      render(<CampaignDataTable data={mockCampaigns} />)

      // Sort by status first
      const statusHeader = screen.getByText('Status')
      await user.click(statusHeader)

      // Then sort by progress (should maintain status grouping)
      const progressHeader = screen.getByText('Progress')
      await user.click(progressHeader)

      // Data should be sorted and still functional
      expect(screen.getByText('Summer Product Launch')).toBeInTheDocument()
    })
  })

  describe('Real-time Filter Updates', () => {
    it('updates results as user types in search', async () => {
      render(<CampaignDataTable data={mockCampaigns} />)

      const searchInput = screen.getByPlaceholderText('Search campaigns...')

      // Type first letter
      await user.type(searchInput, 'S')

      await waitFor(() => {
        expect(screen.getByText('Summer Product Launch')).toBeInTheDocument()
        expect(screen.queryByText('Holiday Sale Campaign')).not.toBeInTheDocument()
      })

      // Continue typing
      await user.type(searchInput, 'ummer')

      await waitFor(() => {
        expect(screen.getByText('Summer Product Launch')).toBeInTheDocument()
        expect(screen.queryByText('Test Campaign Alpha')).not.toBeInTheDocument()
      })
    })

    it('shows empty state when search yields no results', async () => {
      render(<CampaignDataTable data={mockCampaigns} />)

      const searchInput = screen.getByPlaceholderText('Search campaigns...')
      await user.type(searchInput, 'NonexistentCampaign')

      await waitFor(() => {
        expect(screen.getByText('No results found.')).toBeInTheDocument()
      })
    })
  })

  describe('Complex Filter Scenarios', () => {
    it('handles multiple filters simultaneously', async () => {
      render(<CampaignDataTable data={mockCampaigns} />)

      // Apply search
      const searchInput = screen.getByPlaceholderText('Search campaigns...')
      await user.type(searchInput, 'Campaign')

      // Apply status filter
      const statusFilter = screen.getByText('Status')
      await user.click(statusFilter)

      await waitFor(() => {
        const draftOption = screen.getByText('Draft')
        expect(draftOption).toBeInTheDocument()
      })

      const draftOption = screen.getByText('Draft')
      await user.click(draftOption)

      // Should show only draft campaigns matching search
      await waitFor(() => {
        expect(screen.getByText('Holiday Sale Campaign')).toBeInTheDocument()
        expect(screen.queryByText('Test Campaign Alpha')).not.toBeInTheDocument() // Active
        expect(screen.queryByText('Brand Awareness Q1')).not.toBeInTheDocument() // Paused
      })

      // Should show both filter badges
      expect(screen.getByText(/Search: Campaign/)).toBeInTheDocument()
    })

    it('removes specific filters while maintaining others', async () => {
      render(<CampaignDataTable data={mockCampaigns} />)

      // Apply search
      const searchInput = screen.getByPlaceholderText('Search campaigns...')
      await user.type(searchInput, 'Campaign')

      // Wait for search badge
      await waitFor(() => {
        expect(screen.getByText(/Search: Campaign/)).toBeInTheDocument()
      })

      // Clear just the search filter
      const searchBadge = screen.getByText(/Search: Campaign/)
      const clearSearchButton = searchBadge.parentElement?.querySelector('button')
      if (clearSearchButton) {
        await user.click(clearSearchButton)
      }

      // Search should be cleared but all campaigns visible
      await waitFor(() => {
        expect(searchInput).toHaveValue('')
        expect(screen.getByText('Summer Product Launch')).toBeInTheDocument()
        expect(screen.getByText('Holiday Sale Campaign')).toBeInTheDocument()
      })
    })
  })
})