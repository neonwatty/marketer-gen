import { render, screen, fireEvent, waitFor } from '@testing-library/react'
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
    channels: ['Social', 'Display', 'YouTube', 'Influencer'],
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
    title: 'Cancelled Campaign',
    description: 'This campaign was cancelled',
    status: 'cancelled',
    createdAt: 'Oct 1, 2023',
    progress: 30,
    contentPieces: 2,
    channels: ['Social'],
    budget: 8000
  }
]

describe('CampaignDataTable Component', () => {
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

  describe('Basic Rendering', () => {
    it('renders campaign data table with all campaigns', () => {
      render(<CampaignDataTable data={mockCampaigns} />)

      // Check table headers
      expect(screen.getByText('Campaign')).toBeInTheDocument()
      expect(screen.getByText('Status')).toBeInTheDocument()
      expect(screen.getByText('Progress')).toBeInTheDocument()
      expect(screen.getByText('Channels')).toBeInTheDocument()
      expect(screen.getByText('Content')).toBeInTheDocument()

      // Check campaign data
      expect(screen.getByText('Summer Product Launch')).toBeInTheDocument()
      expect(screen.getByText('Holiday Sale Campaign')).toBeInTheDocument()
      expect(screen.getByText('Brand Awareness Q1')).toBeInTheDocument()
    })

    it('renders campaign titles and descriptions', () => {
      render(<CampaignDataTable data={mockCampaigns} />)

      expect(screen.getByText('Multi-channel campaign for new product line launch')).toBeInTheDocument()
      expect(screen.getByText('Black Friday promotional campaign')).toBeInTheDocument()
    })
  })

  describe('Status Badges', () => {
    it('renders status badges with correct labels', () => {
      render(<CampaignDataTable data={mockCampaigns} />)

      expect(screen.getByText('Active')).toBeInTheDocument()
      expect(screen.getByText('Draft')).toBeInTheDocument()
      expect(screen.getByText('Paused')).toBeInTheDocument()
      expect(screen.getByText('Completed')).toBeInTheDocument()
      expect(screen.getByText('Cancelled')).toBeInTheDocument()
    })

    it('applies correct CSS classes to status badges', () => {
      render(<CampaignDataTable data={mockCampaigns} />)

      const activeBadge = screen.getByText('Active')
      const draftBadge = screen.getByText('Draft')
      const cancelledBadge = screen.getByText('Cancelled')

      expect(activeBadge).toHaveClass('bg-green-100')
      expect(draftBadge).toHaveClass('bg-slate-100')
      expect(cancelledBadge).toHaveClass('bg-red-100')
    })
  })

  describe('Progress Display', () => {
    it('renders progress bars with correct values', () => {
      render(<CampaignDataTable data={mockCampaigns} />)

      // Check progress percentages are displayed
      expect(screen.getByText('75%')).toBeInTheDocument()
      expect(screen.getByText('25%')).toBeInTheDocument()
      expect(screen.getByText('100%')).toBeInTheDocument()
    })

    it('renders progress bars as visual elements', () => {
      render(<CampaignDataTable data={mockCampaigns} />)

      // Progress bars should be present (look for progressbar role)
      const progressBars = screen.getAllByRole('progressbar')
      expect(progressBars.length).toBeGreaterThan(0)
    })
  })

  describe('Channel Display', () => {
    it('displays channel badges for campaigns', () => {
      render(<CampaignDataTable data={mockCampaigns} />)

      expect(screen.getByText('Email')).toBeInTheDocument()
      expect(screen.getByText('Social')).toBeInTheDocument()
      expect(screen.getByText('Blog')).toBeInTheDocument()
      expect(screen.getByText('Display')).toBeInTheDocument()
    })

    it('shows overflow indicator for campaigns with many channels', () => {
      render(<CampaignDataTable data={mockCampaigns} />)

      // Brand Awareness Q1 has 4 channels, should show +2 overflow
      expect(screen.getByText('+2')).toBeInTheDocument()
    })
  })

  describe('Metrics Display', () => {
    it('displays content piece counts', () => {
      render(<CampaignDataTable data={mockCampaigns} />)

      expect(screen.getByText('12')).toBeInTheDocument() // pieces count
      expect(screen.getByText('3')).toBeInTheDocument()
      expect(screen.getAllByText('pieces')).toHaveLength(5) // "pieces" label appears for each campaign
    })

    it('displays formatted budget values', () => {
      render(<CampaignDataTable data={mockCampaigns} />)

      expect(screen.getByText('$25,000')).toBeInTheDocument()
      expect(screen.getByText('$15,000')).toBeInTheDocument()
      expect(screen.getByText('$40,000')).toBeInTheDocument()
    })

    it('displays formatted impression numbers', () => {
      render(<CampaignDataTable data={mockCampaigns} />)

      expect(screen.getByText('125K')).toBeInTheDocument() // 125,000 formatted
      expect(screen.getByText('300K')).toBeInTheDocument() // 300,000 formatted
      expect(screen.getByText('75K')).toBeInTheDocument()  // 75,000 formatted
    })

    it('displays engagement percentages', () => {
      render(<CampaignDataTable data={mockCampaigns} />)

      expect(screen.getByText('4.2%')).toBeInTheDocument()
      expect(screen.getByText('3.8%')).toBeInTheDocument()
      expect(screen.getByText('8.5%')).toBeInTheDocument()
    })

    it('shows dash for missing metrics', () => {
      render(<CampaignDataTable data={mockCampaigns} />)

      // Draft campaign should show dashes for missing metrics
      const dashElements = screen.getAllByText('-')
      expect(dashElements.length).toBeGreaterThan(0)
    })
  })

  describe('Row Actions', () => {
    it('renders action dropdown menus for each campaign', () => {
      render(<CampaignDataTable data={mockCampaigns} {...mockHandlers} />)

      const actionButtons = screen.getAllByText('Open menu')
      expect(actionButtons).toHaveLength(mockCampaigns.length)
    })

    it('calls onView when view action is clicked', async () => {
      render(<CampaignDataTable data={mockCampaigns} {...mockHandlers} />)

      const firstActionButton = screen.getAllByLabelText('Open menu')[0]
      await user.click(firstActionButton)

      await waitFor(() => {
        const viewButton = screen.getByText('View details')
        expect(viewButton).toBeInTheDocument()
      })

      const viewButton = screen.getByText('View details')
      await user.click(viewButton)

      expect(mockHandlers.onView).toHaveBeenCalledWith(mockCampaigns[0])
    })

    it('calls onEdit when edit action is clicked', async () => {
      render(<CampaignDataTable data={mockCampaigns} {...mockHandlers} />)

      const firstActionButton = screen.getAllByLabelText('Open menu')[0]
      await user.click(firstActionButton)

      await waitFor(() => {
        const editButton = screen.getByText('Edit campaign')
        expect(editButton).toBeInTheDocument()
      })

      const editButton = screen.getByText('Edit campaign')
      await user.click(editButton)

      expect(mockHandlers.onEdit).toHaveBeenCalledWith(mockCampaigns[0])
    })

    it('calls onCopy when duplicate action is clicked', async () => {
      render(<CampaignDataTable data={mockCampaigns} {...mockHandlers} />)

      const firstActionButton = screen.getAllByLabelText('Open menu')[0]
      await user.click(firstActionButton)

      await waitFor(() => {
        const copyButton = screen.getByText('Duplicate')
        expect(copyButton).toBeInTheDocument()
      })

      const copyButton = screen.getByText('Duplicate')
      await user.click(copyButton)

      expect(mockHandlers.onCopy).toHaveBeenCalledWith(mockCampaigns[0])
    })

    it('calls onDelete when delete action is clicked', async () => {
      render(<CampaignDataTable data={mockCampaigns} {...mockHandlers} />)

      const firstActionButton = screen.getAllByLabelText('Open menu')[0]
      await user.click(firstActionButton)

      await waitFor(() => {
        const deleteButton = screen.getByText('Delete')
        expect(deleteButton).toBeInTheDocument()
      })

      const deleteButton = screen.getByText('Delete')
      await user.click(deleteButton)

      expect(mockHandlers.onDelete).toHaveBeenCalledWith(mockCampaigns[0])
    })

    it('styles delete action as destructive', async () => {
      render(<CampaignDataTable data={mockCampaigns} {...mockHandlers} />)

      const firstActionButton = screen.getAllByLabelText('Open menu')[0]
      await user.click(firstActionButton)

      await waitFor(() => {
        const deleteButton = screen.getByText('Delete')
        expect(deleteButton.closest('[data-variant="destructive"]')).toBeInTheDocument()
      })
    })
  })

  describe('Row Click Behavior', () => {
    it('calls onView when row is clicked', async () => {
      render(<CampaignDataTable data={mockCampaigns} {...mockHandlers} />)

      const firstRow = screen.getByText('Summer Product Launch').closest('tr')
      await user.click(firstRow!)

      expect(mockHandlers.onView).toHaveBeenCalledWith(mockCampaigns[0])
    })

    it('adds cursor-pointer class when onView is provided', () => {
      render(<CampaignDataTable data={mockCampaigns} {...mockHandlers} />)

      const firstRow = screen.getByText('Summer Product Launch').closest('tr')
      expect(firstRow).toHaveClass('cursor-pointer')
    })
  })

  describe('Search and Filter Integration', () => {
    it('includes search functionality', () => {
      render(<CampaignDataTable data={mockCampaigns} />)

      expect(screen.getByPlaceholderText('Search campaigns...')).toBeInTheDocument()
    })

    it('includes status filter dropdown', () => {
      render(<CampaignDataTable data={mockCampaigns} />)

      // Should have status filter
      expect(screen.getByText('Status')).toBeInTheDocument()
    })

    it('filters campaigns by search term', async () => {
      render(<CampaignDataTable data={mockCampaigns} />)

      const searchInput = screen.getByPlaceholderText('Search campaigns...')
      await user.type(searchInput, 'Summer')

      // Only Summer campaign should be visible
      expect(screen.getByText('Summer Product Launch')).toBeInTheDocument()
      expect(screen.queryByText('Holiday Sale Campaign')).not.toBeInTheDocument()
    })
  })

  describe('Export Functionality', () => {
    it('calls onExport when export button is clicked', async () => {
      render(<CampaignDataTable data={mockCampaigns} {...mockHandlers} />)

      const exportButton = screen.getByText('Export')
      await user.click(exportButton)

      expect(mockHandlers.onExport).toHaveBeenCalled()
    })
  })

  describe('Empty State', () => {
    it('shows empty state when no campaigns provided', () => {
      render(<CampaignDataTable data={[]} />)

      expect(screen.getByText('No results found.')).toBeInTheDocument()
    })
  })

  describe('Data Formatting', () => {
    it('formats large numbers correctly', () => {
      const campaignWithLargeNumbers: CampaignTableData = {
        id: '6',
        title: 'Large Campaign',
        description: 'Campaign with large metrics',
        status: 'active',
        createdAt: 'Jan 1, 2024',
        progress: 50,
        contentPieces: 5,
        channels: ['Email'],
        impressions: 1500000, // Should format to 1.5M
        conversions: 25000,   // Should format to 25K
      }

      render(<CampaignDataTable data={[campaignWithLargeNumbers]} />)

      expect(screen.getByText('1.5M')).toBeInTheDocument()
      expect(screen.getByText('25K')).toBeInTheDocument()
    })

    it('handles campaigns without optional metrics', () => {
      const minimalCampaign: CampaignTableData = {
        id: '7',
        title: 'Minimal Campaign',
        description: 'Campaign with minimal data',
        status: 'draft',
        createdAt: 'Jan 1, 2024',
        progress: 10,
        contentPieces: 1,
        channels: ['Email'],
      }

      render(<CampaignDataTable data={[minimalCampaign]} />)

      expect(screen.getByText('Minimal Campaign')).toBeInTheDocument()
      // Should show dashes for missing metrics
      const dashElements = screen.getAllByText('-')
      expect(dashElements.length).toBeGreaterThan(0)
    })
  })
})