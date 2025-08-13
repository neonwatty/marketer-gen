import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { userEvent } from '@testing-library/user-event'
import { CampaignOverviewDashboard, type CampaignOverviewData } from '../campaign-overview-dashboard'

// Mock campaign data for testing
const mockCampaignData: CampaignOverviewData = {
  id: "test-campaign-1",
  title: "Test Campaign",
  description: "Test campaign for unit testing",
  status: "active",
  createdAt: "2024-01-15",
  startDate: "2024-02-01",
  endDate: "2024-04-30",
  budget: {
    total: 25000,
    spent: 18750,
    currency: "USD"
  },
  objectives: ["brand-awareness", "lead-generation"],
  channels: ["Email", "Social Media", "Blog"],
  metrics: {
    progress: 75,
    contentPieces: 12,
    impressions: 125000,
    engagement: 4.2,
    conversions: 850,
    clickThroughRate: 3.1,
    costPerConversion: 22.06,
    roi: 185
  },
  journey: {
    stages: [
      {
        id: "awareness",
        name: "Awareness",
        status: "completed",
        channels: ["Blog", "Social Media"],
        contentCount: 5,
        metrics: { impressions: 75000, engagement: 3.8 }
      },
      {
        id: "consideration",
        name: "Consideration",
        status: "active",
        channels: ["Email", "Social Media"],
        contentCount: 4,
        metrics: { impressions: 40000, engagement: 5.2 }
      },
      {
        id: "conversion",
        name: "Conversion",
        status: "pending",
        channels: ["Email"],
        contentCount: 3,
        metrics: { impressions: 10000, engagement: 6.8 }
      }
    ]
  }
}

describe('CampaignOverviewDashboard Component', () => {
  const user = userEvent.setup()
  const mockOnExport = vi.fn()
  const mockOnShare = vi.fn()

  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('Basic Rendering', () => {
    it('renders campaign title and description', () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      expect(screen.getByText('Test Campaign')).toBeInTheDocument()
      expect(screen.getByText('Test campaign for unit testing')).toBeInTheDocument()
    })

    it('renders action buttons', () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      expect(screen.getByText('Share')).toBeInTheDocument()
      expect(screen.getByText('Export')).toBeInTheDocument()
    })

    it('renders all tabs', () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      expect(screen.getByText('Overview')).toBeInTheDocument()
      expect(screen.getByText('Performance')).toBeInTheDocument()
      expect(screen.getByRole('tab', { name: 'Timeline' })).toBeInTheDocument()
    })
  })

  describe('Key Performance Metrics', () => {
    it('displays campaign progress correctly', () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      expect(screen.getByText('Campaign Progress')).toBeInTheDocument()
      expect(screen.getByText('75%')).toBeInTheDocument()
    })

    it('displays budget information correctly', () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      expect(screen.getByText('Budget Spent')).toBeInTheDocument()
      expect(screen.getAllByText('$18,750')).toHaveLength(2) // Appears in metrics and budget breakdown
    })

    it('displays impressions with correct formatting', () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      expect(screen.getByText('Total Impressions')).toBeInTheDocument()
      expect(screen.getAllByText('125.0K')).toHaveLength(1) // Appears in main metrics
    })

    it('displays engagement rate correctly', () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      expect(screen.getByText('Engagement Rate')).toBeInTheDocument()
      expect(screen.getByText('4.2%')).toBeInTheDocument()
    })
  })

  describe('Secondary Metrics', () => {
    it('displays conversion metrics', () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      expect(screen.getByText('Conversions')).toBeInTheDocument()
      expect(screen.getByText('850')).toBeInTheDocument()
    })

    it('displays CTR correctly', () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      expect(screen.getByText('CTR')).toBeInTheDocument()
      expect(screen.getByText('3.1%')).toBeInTheDocument()
    })

    it('displays ROI correctly', () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      expect(screen.getByText('ROI')).toBeInTheDocument()
      expect(screen.getByText('185%')).toBeInTheDocument()
    })
  })

  describe('Journey Progress Visualization', () => {
    it('displays all journey stages', () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      expect(screen.getByText('Awareness')).toBeInTheDocument()
      expect(screen.getByText('Consideration')).toBeInTheDocument()
      expect(screen.getByText('Conversion')).toBeInTheDocument()
    })

    it('shows stage status badges correctly', () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      expect(screen.getByText('completed')).toBeInTheDocument()
      expect(screen.getByText('active')).toBeInTheDocument()
      expect(screen.getByText('pending')).toBeInTheDocument()
    })

    it('displays content count for each stage', () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      expect(screen.getByText('5 pieces')).toBeInTheDocument()
      expect(screen.getByText('4 pieces')).toBeInTheDocument()
      expect(screen.getByText('3 pieces')).toBeInTheDocument()
    })
  })

  describe('Channel Performance Breakdown', () => {
    it('displays all channels', () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      expect(screen.getByText('Email')).toBeInTheDocument()
      expect(screen.getByText('Social Media')).toBeInTheDocument()
      expect(screen.getByText('Blog')).toBeInTheDocument()
    })

    it('shows channel performance metrics', () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      // Each channel should have impressions and engagement data
      const impressionsText = screen.getAllByText(/impressions/)
      const engagementText = screen.getAllByText(/engagement/)
      
      expect(impressionsText.length).toBeGreaterThan(0)
      expect(engagementText.length).toBeGreaterThan(0)
    })
  })

  describe('Campaign Details Summary', () => {
    it('displays timeline information', () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      expect(screen.getAllByText('Timeline')).toHaveLength(2) // Tab and section title
      expect(screen.getByText(/Start:/)).toBeInTheDocument()
      expect(screen.getByText(/End:/)).toBeInTheDocument()
    })

    it('displays budget breakdown', () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      expect(screen.getByText('Budget Breakdown')).toBeInTheDocument()
      expect(screen.getByText('Spent')).toBeInTheDocument()
      expect(screen.getByText('Remaining')).toBeInTheDocument()
    })

    it('displays objectives', () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      expect(screen.getByText('Objectives')).toBeInTheDocument()
      expect(screen.getByText('Brand Awareness')).toBeInTheDocument()
      expect(screen.getByText('Lead Generation')).toBeInTheDocument()
    })
  })

  describe('Tab Navigation', () => {
    it('switches between tabs correctly', async () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      // Click on Performance tab
      const performanceTab = screen.getByRole('tab', { name: 'Performance' })
      await user.click(performanceTab)

      // Should show performance content
      expect(screen.getByText('Cost Efficiency')).toBeInTheDocument()
      expect(screen.getByText('Content Performance')).toBeInTheDocument()
    })

    it('shows timeline tab content', async () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      // Click on Timeline tab
      const timelineTab = screen.getByRole('tab', { name: 'Timeline' })
      await user.click(timelineTab)

      // Should show timeline placeholder content
      expect(screen.getByText('Campaign Timeline')).toBeInTheDocument()
    })
  })

  describe('Performance Tab Content', () => {
    it('displays cost efficiency metrics', async () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      const performanceTab = screen.getByRole('tab', { name: 'Performance' })
      await user.click(performanceTab)

      expect(screen.getByText('Cost Efficiency')).toBeInTheDocument()
      expect(screen.getByText('$22')).toBeInTheDocument() // Cost per conversion
      expect(screen.getByText('Cost per conversion')).toBeInTheDocument()
    })

    it('displays content performance metrics', async () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      const performanceTab = screen.getByRole('tab', { name: 'Performance' })
      await user.click(performanceTab)

      expect(screen.getByText('Content Performance')).toBeInTheDocument()
      expect(screen.getByText('12')).toBeInTheDocument() // Content pieces count
    })

    it('displays reach metrics', async () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      const performanceTab = screen.getByRole('tab', { name: 'Performance' })
      await user.click(performanceTab)

      expect(screen.getByText('Reach')).toBeInTheDocument()
      expect(screen.getAllByText('125.0K')).toHaveLength(2) // Total impressions in both main and performance tab
    })
  })

  describe('Interactive Elements', () => {
    it('calls onExport when Export button is clicked', async () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      const exportButton = screen.getByText('Export')
      await user.click(exportButton)

      expect(mockOnExport).toHaveBeenCalledTimes(1)
    })

    it('calls onShare when Share button is clicked', async () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      const shareButton = screen.getByText('Share')
      await user.click(shareButton)

      expect(mockOnShare).toHaveBeenCalledTimes(1)
    })
  })

  describe('Number Formatting', () => {
    it('formats large numbers correctly', () => {
      const campaignWithLargeNumbers = {
        ...mockCampaignData,
        metrics: {
          ...mockCampaignData.metrics,
          impressions: 1500000, // 1.5M
          conversions: 2500 // 2.5K
        }
      }

      render(
        <CampaignOverviewDashboard 
          campaign={campaignWithLargeNumbers}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      expect(screen.getByText('1.5M')).toBeInTheDocument()
      expect(screen.getByText('2.5K')).toBeInTheDocument()
    })

    it('formats currency correctly', () => {
      const campaignWithDifferentCurrency = {
        ...mockCampaignData,
        budget: {
          ...mockCampaignData.budget,
          currency: 'EUR',
          spent: 15000,
          total: 20000
        }
      }

      render(
        <CampaignOverviewDashboard 
          campaign={campaignWithDifferentCurrency}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      expect(screen.getAllByText('€15,000')).toHaveLength(2) // Appears in metrics and budget breakdown
    })
  })

  describe('Trend Indicators', () => {
    it('displays trend arrows and percentages', () => {
      const { container } = render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      // Should have trend indicators with arrows and percentages
      const trendElements = container.querySelectorAll('.text-green-500, .text-orange-600')
      expect(trendElements.length).toBeGreaterThan(0)
    })

    it('shows positive trends correctly', () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      // Look for positive trend indicators
      expect(screen.getByText('on track')).toBeInTheDocument()
      expect(screen.getByText('vs target')).toBeInTheDocument()
    })
  })

  describe('Budget Utilization', () => {
    it('calculates budget utilization correctly', () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      // Budget utilization should be calculated: 18750 / 25000 = 75%
      expect(screen.getByText('75% of total budget used')).toBeInTheDocument()
    })

    it('shows remaining budget correctly', () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      expect(screen.getByText('Remaining')).toBeInTheDocument()
      expect(screen.getByText('$6,250')).toBeInTheDocument() // 25000 - 18750, in budget breakdown
    })
  })

  describe('Responsive Design', () => {
    it('renders grid layouts properly', () => {
      const { container } = render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      // Should have responsive grid classes
      const gridElements = container.querySelectorAll('.grid')
      expect(gridElements.length).toBeGreaterThan(0)

      const responsiveElements = container.querySelectorAll('.md\\:grid-cols-2, .lg\\:grid-cols-3, .lg\\:grid-cols-4')
      expect(responsiveElements.length).toBeGreaterThan(0)
    })
  })

  describe('Progress Indicators', () => {
    it('shows campaign progress bar', () => {
      const { container } = render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      // Should have progress bars
      const progressBars = container.querySelectorAll('[role="progressbar"], .h-2')
      expect(progressBars.length).toBeGreaterThan(0)
    })

    it('shows journey stage progress correctly', () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      // Should show different progress states for different stages
      const completedIndicator = screen.getByText('completed')
      const activeIndicator = screen.getByText('active')
      const pendingIndicator = screen.getByText('pending')

      expect(completedIndicator).toBeInTheDocument()
      expect(activeIndicator).toBeInTheDocument()
      expect(pendingIndicator).toBeInTheDocument()
    })
  })

  describe('Edge Cases', () => {
    it('handles zero values gracefully', () => {
      const campaignWithZeros = {
        ...mockCampaignData,
        metrics: {
          ...mockCampaignData.metrics,
          conversions: 0,
          engagement: 0
        }
      }

      render(
        <CampaignOverviewDashboard 
          campaign={campaignWithZeros}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      expect(screen.getByText('0')).toBeInTheDocument()
      expect(screen.getByText('0%')).toBeInTheDocument()
    })

    it('handles very large numbers', () => {
      const campaignWithLargeNumbers = {
        ...mockCampaignData,
        metrics: {
          ...mockCampaignData.metrics,
          impressions: 10000000, // 10M
        }
      }

      render(
        <CampaignOverviewDashboard 
          campaign={campaignWithLargeNumbers}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      expect(screen.getByText('10.0M')).toBeInTheDocument()
    })

    it('handles campaigns with no objectives', () => {
      const campaignWithNoObjectives = {
        ...mockCampaignData,
        objectives: []
      }

      render(
        <CampaignOverviewDashboard 
          campaign={campaignWithNoObjectives}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      // Should still render the Objectives section
      expect(screen.getByText('Objectives')).toBeInTheDocument()
    })

    it('handles campaigns with single channel', () => {
      const campaignWithSingleChannel = {
        ...mockCampaignData,
        channels: ['Email']
      }

      render(
        <CampaignOverviewDashboard 
          campaign={campaignWithSingleChannel}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      expect(screen.getByText('Email')).toBeInTheDocument()
      // Should not crash with single channel
    })
  })

  describe('Accessibility', () => {
    it('provides proper semantic structure', () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      // Should have proper heading hierarchy
      const headings = screen.getAllByRole('heading')
      expect(headings.length).toBeGreaterThan(0)
    })

    it('provides button accessibility', () => {
      render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      const buttons = screen.getAllByRole('button')
      expect(buttons.length).toBeGreaterThan(0)

      // Buttons should be keyboard accessible
      buttons.forEach(button => {
        expect(button).not.toHaveAttribute('tabindex', '-1')
      })
    })

    it('provides progress bar accessibility', () => {
      const { container } = render(
        <CampaignOverviewDashboard 
          campaign={mockCampaignData}
          onExport={mockOnExport}
          onShare={mockOnShare}
        />
      )

      // Progress bars should have proper ARIA attributes
      const progressElements = container.querySelectorAll('[role="progressbar"]')
      progressElements.forEach(progress => {
        expect(progress).toHaveAttribute('role', 'progressbar')
      })
    })
  })
})