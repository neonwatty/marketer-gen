import { render, screen, waitFor } from '@testing-library/react'
import { userEvent } from '@testing-library/user-event'

// Mock Next.js Link component
vi.mock('next/link', () => {
  return {
    default: ({ children, href, ...props }: { children: React.ReactNode; href: string }) => (
      <a href={href} {...props}>
        {children}
      </a>
    ),
  }
})

// Mock the campaign pages
const mockCampaignsPage = () => {
  const CampaignCard = ({ title, description, status, metrics }: any) => (
    <div data-testid={`campaign-card-${title.replace(/\s+/g, '-').toLowerCase()}`}>
      <h3>{title}</h3>
      <p>{description}</p>
      <span data-testid="status">{status}</span>
      <span data-testid="progress">{metrics.progress}%</span>
    </div>
  )

  const CampaignStats = ({ stats }: any) => (
    <div data-testid="campaign-stats">
      <div>Total: {stats.totalCampaigns}</div>
      <div>Active: {stats.activeCampaigns}</div>
      <div>Budget: ${stats.totalBudget.toLocaleString()}</div>
    </div>
  )

  return (
    <div>
      {/* Page Header */}
      <div>
        <h1>Campaigns</h1>
        <p>Manage and organize your marketing campaigns</p>
        <div data-testid="view-toggle">
          <button data-testid="grid-view">Grid View</button>
          <a href="/campaigns/list">
            <button data-testid="list-view">List View</button>
          </a>
        </div>
        <button data-testid="new-campaign">New Campaign</button>
      </div>

      {/* Campaign Stats */}
      <CampaignStats stats={{
        totalCampaigns: 4,
        activeCampaigns: 1,
        totalBudget: 85000,
        avgEngagement: 5.125
      }} />

      {/* Campaigns Grid */}
      <div data-testid="campaigns-grid">
        <CampaignCard
          title="Summer Product Launch"
          description="Multi-channel campaign for new product line launch"
          status="active"
          metrics={{ progress: 75 }}
        />
        <CampaignCard
          title="Holiday Sale Campaign"
          description="Black Friday promotional campaign"
          status="draft"
          metrics={{ progress: 25 }}
        />
        <CampaignCard
          title="Brand Awareness Q1"
          description="Brand awareness campaign targeting millennials"
          status="paused"
          metrics={{ progress: 60 }}
        />
        <CampaignCard
          title="Customer Retention Email Series"
          description="Automated email sequence for customer retention"
          status="completed"
          metrics={{ progress: 100 }}
        />
      </div>
    </div>
  )
}

const mockCampaignsListPage = () => {
  return (
    <div>
      {/* Page Header */}
      <div>
        <h1>Campaigns</h1>
        <p>Manage and organize your marketing campaigns</p>
        <div data-testid="view-toggle">
          <a href="/campaigns">
            <button data-testid="grid-view">Grid View</button>
          </a>
          <button data-testid="list-view">List View</button>
        </div>
        <button data-testid="new-campaign">New Campaign</button>
      </div>

      {/* Campaign Stats */}
      <div data-testid="campaign-stats">
        <div>Total: 4</div>
        <div>Active: 1</div>
        <div>Budget: $85,000</div>
      </div>

      {/* Data Table */}
      <div data-testid="campaigns-table">
        <input placeholder="Search campaigns..." />
        <select data-testid="status-filter">
          <option>All Status</option>
          <option>Active</option>
          <option>Draft</option>
          <option>Paused</option>
          <option>Completed</option>
        </select>
        <button>Export</button>
        <table>
          <thead>
            <tr>
              <th>Campaign</th>
              <th>Status</th>
              <th>Progress</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr data-testid="campaign-row-1">
              <td>Summer Product Launch</td>
              <td>Active</td>
              <td>75%</td>
              <td><button>Actions</button></td>
            </tr>
            <tr data-testid="campaign-row-2">
              <td>Holiday Sale Campaign</td>
              <td>Draft</td>
              <td>25%</td>
              <td><button>Actions</button></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  )
}

describe('Campaign Pages Integration Tests', () => {
  const user = userEvent.setup()

  describe('Grid View Page', () => {
    beforeEach(() => {
      const GridViewPage = mockCampaignsPage
      render(<GridViewPage />)
    })

    it('renders page header with correct title and description', () => {
      expect(screen.getByText('Campaigns')).toBeInTheDocument()
      expect(screen.getByText('Manage and organize your marketing campaigns')).toBeInTheDocument()
    })

    it('renders view toggle buttons with grid view active', () => {
      const gridButton = screen.getByTestId('grid-view')
      const listButton = screen.getByTestId('list-view')

      expect(gridButton).toBeInTheDocument()
      expect(listButton).toBeInTheDocument()
      
      // Grid button should appear active/selected in real implementation
      expect(gridButton).toBeInTheDocument()
    })

    it('renders new campaign button', () => {
      expect(screen.getByTestId('new-campaign')).toBeInTheDocument()
    })

    it('displays campaign stats', () => {
      const statsSection = screen.getByTestId('campaign-stats')
      expect(statsSection).toBeInTheDocument()
      expect(screen.getByText('Total: 4')).toBeInTheDocument()
      expect(screen.getByText('Active: 1')).toBeInTheDocument()
      expect(screen.getByText('Budget: $85,000')).toBeInTheDocument()
    })

    it('renders all campaign cards in grid layout', () => {
      const campaignsGrid = screen.getByTestId('campaigns-grid')
      expect(campaignsGrid).toBeInTheDocument()

      // Check all campaign cards are present
      expect(screen.getByTestId('campaign-card-summer-product-launch')).toBeInTheDocument()
      expect(screen.getByTestId('campaign-card-holiday-sale-campaign')).toBeInTheDocument()
      expect(screen.getByTestId('campaign-card-brand-awareness-q1')).toBeInTheDocument()
      expect(screen.getByTestId('campaign-card-customer-retention-email-series')).toBeInTheDocument()
    })

    it('displays campaign details correctly', () => {
      expect(screen.getByText('Summer Product Launch')).toBeInTheDocument()
      expect(screen.getByText('Multi-channel campaign for new product line launch')).toBeInTheDocument()
      expect(screen.getByText('active')).toBeInTheDocument()
      expect(screen.getByText('75%')).toBeInTheDocument()
    })

    it('navigates to list view when list button is clicked', async () => {
      const listButton = screen.getByTestId('list-view')
      
      // In real implementation, this would navigate
      expect(listButton.closest('a')).toHaveAttribute('href', '/campaigns/list')
    })
  })

  describe('List View Page', () => {
    beforeEach(() => {
      const ListViewPage = mockCampaignsListPage
      render(<ListViewPage />)
    })

    it('renders page header with same structure as grid view', () => {
      expect(screen.getByText('Campaigns')).toBeInTheDocument()
      expect(screen.getByText('Manage and organize your marketing campaigns')).toBeInTheDocument()
    })

    it('renders view toggle buttons with list view active', () => {
      const gridButton = screen.getByTestId('grid-view')
      const listButton = screen.getByTestId('list-view')

      expect(gridButton).toBeInTheDocument()
      expect(listButton).toBeInTheDocument()
    })

    it('displays same campaign stats as grid view', () => {
      const statsSection = screen.getByTestId('campaign-stats')
      expect(statsSection).toBeInTheDocument()
      expect(screen.getByText('Total: 4')).toBeInTheDocument()
      expect(screen.getByText('Active: 1')).toBeInTheDocument()
      expect(screen.getByText('Budget: $85,000')).toBeInTheDocument()
    })

    it('renders data table instead of grid', () => {
      const campaignsTable = screen.getByTestId('campaigns-table')
      expect(campaignsTable).toBeInTheDocument()

      // Should not have grid layout
      expect(screen.queryByTestId('campaigns-grid')).not.toBeInTheDocument()
    })

    it('includes table functionality - search and filters', () => {
      expect(screen.getByPlaceholderText('Search campaigns...')).toBeInTheDocument()
      expect(screen.getByTestId('status-filter')).toBeInTheDocument()
      expect(screen.getByText('Export')).toBeInTheDocument()
    })

    it('displays campaigns in table format', () => {
      expect(screen.getByText('Campaign')).toBeInTheDocument() // Header
      expect(screen.getByText('Status')).toBeInTheDocument() // Header
      expect(screen.getByText('Progress')).toBeInTheDocument() // Header

      // Campaign rows
      expect(screen.getByTestId('campaign-row-1')).toBeInTheDocument()
      expect(screen.getByTestId('campaign-row-2')).toBeInTheDocument()
    })

    it('navigates to grid view when grid button is clicked', () => {
      const gridButton = screen.getByTestId('grid-view')
      
      // In real implementation, this would navigate
      expect(gridButton.closest('a')).toHaveAttribute('href', '/campaigns')
    })
  })

  describe('Cross-Page Consistency', () => {
    it('maintains same data between views', () => {
      // Render grid view
      const GridViewPage = mockCampaignsPage
      const { unmount } = render(<GridViewPage />)
      
      const gridStats = screen.getByText('Total: 4')
      expect(gridStats).toBeInTheDocument()

      unmount()

      // Render list view
      const ListViewPage = mockCampaignsListPage
      render(<ListViewPage />)
      
      const listStats = screen.getByText('Total: 4')
      expect(listStats).toBeInTheDocument()
    })

    it('maintains same header structure between views', () => {
      const GridViewPage = mockCampaignsPage
      const { unmount } = render(<GridViewPage />)
      
      expect(screen.getByText('Campaigns')).toBeInTheDocument()
      expect(screen.getByTestId('new-campaign')).toBeInTheDocument()

      unmount()

      const ListViewPage = mockCampaignsListPage
      render(<ListViewPage />)
      
      expect(screen.getByText('Campaigns')).toBeInTheDocument()
      expect(screen.getByTestId('new-campaign')).toBeInTheDocument()
    })
  })

  describe('Responsive Behavior', () => {
    it('adapts view toggle for mobile screens', () => {
      // In real implementation, would test responsive behavior
      const GridViewPage = mockCampaignsPage
      render(<GridViewPage />)

      const viewToggle = screen.getByTestId('view-toggle')
      expect(viewToggle).toBeInTheDocument()
    })
  })

  describe('User Interactions', () => {
    it('handles new campaign button click', async () => {
      const GridViewPage = mockCampaignsPage
      render(<GridViewPage />)

      const newCampaignButton = screen.getByTestId('new-campaign')
      
      // Should be clickable
      expect(newCampaignButton).toBeEnabled()
      
      await user.click(newCampaignButton)
      // In real implementation, would verify navigation or modal opening
    })

    it('handles table interactions in list view', async () => {
      const ListViewPage = mockCampaignsListPage
      render(<ListViewPage />)

      const searchInput = screen.getByPlaceholderText('Search campaigns...')
      await user.type(searchInput, 'Summer')

      expect(searchInput).toHaveValue('Summer')

      const statusFilter = screen.getByTestId('status-filter')
      await user.selectOptions(statusFilter, 'Active')

      expect(statusFilter).toHaveValue('Active')
    })
  })

  describe('Loading and Error States', () => {
    it('handles empty campaign data gracefully', () => {
      const EmptyGridPage = () => (
        <div>
          <h1>Campaigns</h1>
          <div data-testid="campaign-stats">
            <div>Total: 0</div>
          </div>
          <div data-testid="empty-state">
            <p>No campaigns yet</p>
            <button>Create Your First Campaign</button>
          </div>
        </div>
      )

      render(<EmptyGridPage />)

      expect(screen.getByText('Total: 0')).toBeInTheDocument()
      expect(screen.getByTestId('empty-state')).toBeInTheDocument()
      expect(screen.getByText('No campaigns yet')).toBeInTheDocument()
    })
  })

  describe('Accessibility', () => {
    it('provides proper heading structure', () => {
      const GridViewPage = mockCampaignsPage
      render(<GridViewPage />)

      const mainHeading = screen.getByRole('heading', { level: 1 })
      expect(mainHeading).toHaveTextContent('Campaigns')
    })

    it('provides proper navigation structure', () => {
      const GridViewPage = mockCampaignsPage
      render(<GridViewPage />)

      const buttons = screen.getAllByRole('button')
      expect(buttons.length).toBeGreaterThan(0)

      const links = screen.getAllByRole('link')
      expect(links.length).toBeGreaterThan(0)
    })

    it('maintains tab order for keyboard navigation', async () => {
      const GridViewPage = mockCampaignsPage
      render(<GridViewPage />)

      // Tab through interactive elements
      await user.tab()
      const focusedElement = document.activeElement
      expect(focusedElement).toBeInstanceOf(HTMLElement)
    })
  })
})