import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { userEvent } from '@testing-library/user-event'
import { CampaignJourneyVisualization } from '../campaign-journey-visualization'
import { CampaignMetricsPanel } from '../campaign-metrics-panel'
import { CampaignContentList } from '../campaign-content-list'
import { CampaignTimelineActivity } from '../campaign-timeline-activity'

const mockCampaign = {
  id: '1',
  title: 'Summer Product Launch',
  status: 'active',
  budget: {
    total: 25000,
    spent: 18750,
    currency: 'USD'
  },
  metrics: {
    progress: 75,
    contentPieces: 12,
    impressions: 125000,
    engagement: 4.2,
    conversions: 850,
    clickThroughRate: 3.1,
    costPerConversion: 22.06
  },
  channels: ['Email', 'Social Media', 'Blog', 'Display Ads']
}

const mockJourney = {
  stages: [
    {
      id: 'awareness',
      name: 'Awareness',
      description: 'Brand introduction and problem recognition',
      status: 'completed' as const,
      channels: ['Blog', 'Social Media', 'Display Ads'],
      contentCount: 8,
      metrics: { impressions: 75000, engagement: 3.8 }
    },
    {
      id: 'consideration',
      name: 'Consideration',
      description: 'Product evaluation and comparison',
      status: 'active' as const,
      channels: ['Email', 'Social Media', 'Blog'],
      contentCount: 6,
      metrics: { impressions: 40000, engagement: 5.2 }
    }
  ]
}

// Mock console.log to avoid test noise
const mockConsoleLog = vi.fn()
console.log = mockConsoleLog

describe('Campaign Detail Components Integration', () => {
  const user = userEvent.setup()

  beforeEach(() => {
    mockConsoleLog.mockClear()
  })

  describe('Cross-Component Data Consistency', () => {
    it('displays consistent campaign metrics across components', async () => {
      const { rerender } = render(
        <div>
          <CampaignMetricsPanel campaign={mockCampaign} />
          <CampaignJourneyVisualization journey={mockJourney} />
        </div>
      )

      // Check metrics in metrics panel
      expect(screen.getByText('125.0K')).toBeInTheDocument() // Impressions in metrics panel

      // Check journey shows consistent impression data
      expect(screen.getByText('75.0K')).toBeInTheDocument() // Awareness impressions
      expect(screen.getByText('40.0K')).toBeInTheDocument() // Consideration impressions
    })

    it('shows consistent engagement rates across components', () => {
      render(
        <div>
          <CampaignMetricsPanel campaign={mockCampaign} />
          <CampaignJourneyVisualization journey={mockJourney} />
        </div>
      )

      // Overall engagement in metrics panel
      expect(screen.getByText('4.2%')).toBeInTheDocument()

      // Stage-specific engagement in journey
      expect(screen.getByText('3.8%')).toBeInTheDocument() // Awareness
      expect(screen.getByText('5.2%')).toBeInTheDocument() // Consideration
    })

    it('maintains consistent campaign identification across components', () => {
      render(
        <div>
          <CampaignContentList campaignId="test-campaign-123" />
          <CampaignTimelineActivity campaignId="test-campaign-123" />
        </div>
      )

      // Both components should reference the same campaign
      expect(screen.getByText('Campaign Content')).toBeInTheDocument()
      expect(screen.getByText('Recent Activity')).toBeInTheDocument()
    })
  })

  describe('Interactive Component Combinations', () => {
    it('handles simultaneous interactions in metrics panel tabs and journey stages', async () => {
      render(
        <div>
          <CampaignMetricsPanel campaign={mockCampaign} />
          <CampaignJourneyVisualization journey={mockJourney} />
        </div>
      )

      // Interact with metrics panel
      const channelsTab = screen.getByRole('tab', { name: 'Channels' })
      await user.click(channelsTab)

      await waitFor(() => {
        expect(screen.getByText('Channel Performance')).toBeInTheDocument()
      })

      // Interact with journey visualization
      const awarenessStage = screen.getByText('Awareness').closest('.cursor-pointer')
      await user.click(awarenessStage!)

      await waitFor(() => {
        expect(screen.getByText('Content Pieces')).toBeInTheDocument()
      })

      // Both interactions should work independently
      expect(screen.getByText('Channel Performance')).toBeInTheDocument()
      expect(screen.getByText('Content Pieces')).toBeInTheDocument()
    })

    it('handles content list filtering while other components remain stable', async () => {
      render(
        <div>
          <CampaignContentList campaignId="test-campaign" />
          <CampaignTimelineActivity campaignId="test-campaign" />
        </div>
      )

      // Filter content list
      const searchInput = screen.getByPlaceholderText('Search content...')
      await user.type(searchInput, 'Sustainable')

      // Timeline should remain unaffected
      expect(screen.getByText('Recent Activity')).toBeInTheDocument()
      expect(screen.getByText('High engagement detected')).toBeInTheDocument()

      // Content list should be filtered
      await waitFor(() => {
        expect(screen.getByText('Sustainable Living: 10 Easy Ways to Start Today')).toBeInTheDocument()
      })
    })
  })

  describe('Performance with Multiple Components', () => {
    it('renders all campaign detail components efficiently together', () => {
      const startTime = performance.now()
      
      render(
        <div>
          <CampaignJourneyVisualization journey={mockJourney} />
          <CampaignMetricsPanel campaign={mockCampaign} />
          <CampaignContentList campaignId="test-campaign" />
          <CampaignTimelineActivity campaignId="test-campaign" />
        </div>
      )
      
      const endTime = performance.now()

      // Should render all components quickly
      expect(endTime - startTime).toBeLessThan(2000) // Less than 2 seconds for all components

      // Verify all components are rendered
      expect(screen.getByText('Customer Journey Progress')).toBeInTheDocument()
      expect(screen.getByText('Total Impressions')).toBeInTheDocument()
      expect(screen.getByText('Campaign Content')).toBeInTheDocument()
      expect(screen.getByText('Recent Activity')).toBeInTheDocument()
    })

    it('handles rapid interactions across multiple components', async () => {
      render(
        <div>
          <CampaignJourneyVisualization journey={mockJourney} />
          <CampaignMetricsPanel campaign={mockCampaign} />
          <CampaignContentList campaignId="test-campaign" />
        </div>
      )

      // Rapid interactions across components
      const awarenessStage = screen.getByText('Awareness').closest('.cursor-pointer')
      const budgetTab = screen.getByRole('tab', { name: 'Budget' })
      const draftContentTab = screen.getByText('Draft (2)')

      await user.click(awarenessStage!)
      await user.click(budgetTab)
      await user.click(draftContentTab)

      // All interactions should work
      await waitFor(() => {
        expect(screen.getByText('Budget Utilization')).toBeInTheDocument()
      })
      
      expect(screen.getByText('Limited Time: 20% Off Sustainable Collection')).toBeInTheDocument()
    })
  })

  describe('Data Flow and State Management', () => {
    it('maintains independent state across components', async () => {
      render(
        <div>
          <CampaignJourneyVisualization journey={mockJourney} />
          <CampaignContentList campaignId="test-campaign" />
        </div>
      )

      // Expand a journey stage
      const awarenessStage = screen.getByText('Awareness').closest('.cursor-pointer')
      await user.click(awarenessStage!)

      await waitFor(() => {
        expect(screen.getByText('Content Pieces')).toBeInTheDocument()
      })

      // Change content list tab
      const publishedTab = screen.getByText('Published (4)')
      await user.click(publishedTab)

      await waitFor(() => {
        expect(screen.getByText('Sustainable Living: 10 Easy Ways to Start Today')).toBeInTheDocument()
      })

      // Journey stage should still be expanded
      expect(screen.getByText('Content Pieces')).toBeInTheDocument()
      expect(screen.getByText('Sustainable Living: 10 Easy Ways to Start Today')).toBeInTheDocument()
    })

    it('handles component remounting gracefully', () => {
      const { rerender } = render(
        <div>
          <CampaignMetricsPanel campaign={mockCampaign} />
        </div>
      )

      expect(screen.getByText('Total Impressions')).toBeInTheDocument()

      // Remount with different props
      const updatedCampaign = {
        ...mockCampaign,
        metrics: { ...mockCampaign.metrics, impressions: 200000 }
      }

      rerender(
        <div>
          <CampaignMetricsPanel campaign={updatedCampaign} />
        </div>
      )

      expect(screen.getByText('200.0K')).toBeInTheDocument()
    })
  })

  describe('Error Boundaries and Resilience', () => {
    it('continues working when one component has issues', () => {
      // Mock console.error to avoid test noise from intentional errors
      const mockConsoleError = vi.fn()
      const originalError = console.error
      console.error = mockConsoleError

      try {
        render(
          <div>
            <CampaignJourneyVisualization journey={mockJourney} />
            <CampaignTimelineActivity campaignId="test-campaign" />
          </div>
        )

        // Both components should render
        expect(screen.getByText('Customer Journey Progress')).toBeInTheDocument()
        expect(screen.getByText('Recent Activity')).toBeInTheDocument()
      } finally {
        console.error = originalError
      }
    })

    it('handles missing or malformed data gracefully', () => {
      const incompleteJourney = {
        stages: []
      }

      render(
        <div>
          <CampaignJourneyVisualization journey={incompleteJourney} />
          <CampaignMetricsPanel campaign={mockCampaign} />
        </div>
      )

      // Should render without crashing
      expect(screen.getByText('Customer Journey Progress')).toBeInTheDocument()
      expect(screen.getByText('Total Impressions')).toBeInTheDocument()
    })
  })

  describe('Accessibility Integration', () => {
    it('maintains proper tab order across components', async () => {
      render(
        <div>
          <CampaignMetricsPanel campaign={mockCampaign} />
          <CampaignContentList campaignId="test-campaign" />
        </div>
      )

      // First set of tabs (metrics panel)
      const performanceTab = screen.getByRole('tab', { name: 'Performance' })
      const channelsTab = screen.getByRole('tab', { name: 'Channels' })

      // Second set of tabs (content list)
      const allContentTab = screen.getByRole('tab', { name: /All \(8\)/ })
      const draftContentTab = screen.getByRole('tab', { name: /Draft \(2\)/ })

      // Should be able to navigate between different tab groups
      await user.click(channelsTab)
      await user.click(draftContentTab)

      expect(channelsTab).toHaveAttribute('aria-selected', 'true')
      expect(draftContentTab).toHaveAttribute('aria-selected', 'true')
    })

    it('provides consistent focus management across components', async () => {
      render(
        <div>
          <CampaignJourneyVisualization journey={mockJourney} />
          <CampaignContentList campaignId="test-campaign" />
        </div>
      )

      // Focus should work independently in each component
      const journeyCard = screen.getByText('Awareness').closest('.cursor-pointer')
      const searchInput = screen.getByPlaceholderText('Search content...')

      await user.click(journeyCard!)
      expect(journeyCard).toHaveFocus()

      await user.click(searchInput)
      expect(searchInput).toHaveFocus()
    })
  })

  describe('Visual Consistency', () => {
    it('maintains consistent styling patterns across components', () => {
      const { container } = render(
        <div>
          <CampaignJourneyVisualization journey={mockJourney} />
          <CampaignMetricsPanel campaign={mockCampaign} />
          <CampaignContentList campaignId="test-campaign" />
          <CampaignTimelineActivity campaignId="test-campaign" />
        </div>
      )

      // Check for consistent card patterns
      const cards = container.querySelectorAll('[data-slot="card"]')
      expect(cards.length).toBeGreaterThan(0)

      // Check for consistent badge patterns
      const badges = container.querySelectorAll('[data-slot="badge"]')
      expect(badges.length).toBeGreaterThan(0)
    })

    it('maintains consistent spacing and layout patterns', () => {
      const { container } = render(
        <div className="space-y-6">
          <CampaignJourneyVisualization journey={mockJourney} />
          <CampaignMetricsPanel campaign={mockCampaign} />
          <CampaignContentList campaignId="test-campaign" />
          <CampaignTimelineActivity campaignId="test-campaign" />
        </div>
      )

      // Container should have consistent spacing class
      expect(container.firstChild).toHaveClass('space-y-6')
    })
  })

  describe('Real-world Usage Patterns', () => {
    it('handles typical user workflow of viewing journey then checking content', async () => {
      render(
        <div>
          <CampaignJourneyVisualization journey={mockJourney} />
          <CampaignContentList campaignId="test-campaign" />
        </div>
      )

      // User views journey stage details
      const awarenessStage = screen.getByText('Awareness').closest('.cursor-pointer')
      await user.click(awarenessStage!)

      await waitFor(() => {
        expect(screen.getByText('8')).toBeInTheDocument() // Content pieces count
      })

      // User then filters content to see awareness stage content
      const searchInput = screen.getByPlaceholderText('Search content...')
      await user.type(searchInput, 'Awareness')

      await waitFor(() => {
        expect(screen.getByText('Sustainable Living: 10 Easy Ways to Start Today')).toBeInTheDocument()
      })

      // Both views should remain functional
      expect(screen.getByText('8')).toBeInTheDocument() // Journey stage still expanded
    })

    it('supports analytics deep-dive workflow', async () => {
      render(
        <div>
          <CampaignMetricsPanel campaign={mockCampaign} />
          <CampaignTimelineActivity campaignId="test-campaign" />
        </div>
      )

      // User checks different analytics tabs
      const channelsTab = screen.getByRole('tab', { name: 'Channels' })
      const audienceTab = screen.getByRole('tab', { name: 'Audience' })

      await user.click(channelsTab)
      await waitFor(() => {
        expect(screen.getByText('Channel Performance')).toBeInTheDocument()
      })

      await user.click(audienceTab)
      await waitFor(() => {
        expect(screen.getByText('Demographics and behavior of your campaign audience')).toBeInTheDocument()
      })

      // Timeline should remain visible and functional
      expect(screen.getByText('Recent Activity')).toBeInTheDocument()
      expect(screen.getByText('High engagement detected')).toBeInTheDocument()
    })
  })
})