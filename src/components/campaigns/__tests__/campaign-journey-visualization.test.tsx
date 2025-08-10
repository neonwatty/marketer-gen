import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { userEvent } from '@testing-library/user-event'
import { CampaignJourneyVisualization } from '../campaign-journey-visualization'

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
    },
    {
      id: 'conversion',
      name: 'Conversion',
      description: 'Purchase decision and action',
      status: 'active' as const,
      channels: ['Email', 'Landing Pages'],
      contentCount: 4,
      metrics: { impressions: 10000, engagement: 6.8 }
    },
    {
      id: 'retention',
      name: 'Retention',
      description: 'Post-purchase engagement and loyalty',
      status: 'pending' as const,
      channels: ['Email', 'Social Media'],
      contentCount: 0,
      metrics: { impressions: 0, engagement: 0 }
    }
  ]
}

describe('CampaignJourneyVisualization Component', () => {
  const user = userEvent.setup()

  describe('Basic Rendering', () => {
    it('renders journey progress overview', () => {
      render(<CampaignJourneyVisualization journey={mockJourney} />)

      expect(screen.getByText('Customer Journey Progress')).toBeInTheDocument()
      expect(screen.getByText('Track your audience through each stage of the customer journey')).toBeInTheDocument()
    })

    it('renders all journey stages', () => {
      render(<CampaignJourneyVisualization journey={mockJourney} />)

      expect(screen.getByText('Awareness')).toBeInTheDocument()
      expect(screen.getByText('Consideration')).toBeInTheDocument()
      expect(screen.getByText('Conversion')).toBeInTheDocument()
      expect(screen.getByText('Retention')).toBeInTheDocument()
    })

    it('displays stage descriptions', () => {
      render(<CampaignJourneyVisualization journey={mockJourney} />)

      expect(screen.getByText('Brand introduction and problem recognition')).toBeInTheDocument()
      expect(screen.getByText('Product evaluation and comparison')).toBeInTheDocument()
      expect(screen.getByText('Purchase decision and action')).toBeInTheDocument()
      expect(screen.getByText('Post-purchase engagement and loyalty')).toBeInTheDocument()
    })

    it('shows progress percentage', () => {
      render(<CampaignJourneyVisualization journey={mockJourney} />)

      // 1 completed stage out of 4 = 25%
      expect(screen.getByText('25%')).toBeInTheDocument()
      expect(screen.getByText('Complete')).toBeInTheDocument()
    })

    it('displays stage completion status', () => {
      render(<CampaignJourneyVisualization journey={mockJourney} />)

      expect(screen.getByText('1 of 4 stages completed')).toBeInTheDocument()
      expect(screen.getByText('2 stages active')).toBeInTheDocument()
    })
  })

  describe('Stage Status Display', () => {
    it('shows correct status badges for each stage', () => {
      render(<CampaignJourneyVisualization journey={mockJourney} />)

      expect(screen.getByText('Completed')).toBeInTheDocument()
      expect(screen.getAllByText('Active')).toHaveLength(2)
      expect(screen.getByText('Pending')).toBeInTheDocument()
    })

    it('applies correct styling for different statuses', () => {
      render(<CampaignJourneyVisualization journey={mockJourney} />)

      const completedBadge = screen.getByText('Completed')
      const activeBadges = screen.getAllByText('Active')
      const pendingBadge = screen.getByText('Pending')

      expect(completedBadge).toHaveClass('text-green-700')
      expect(activeBadges[0]).toHaveClass('text-blue-700')
      expect(pendingBadge).toHaveClass('text-slate-700')
    })
  })

  describe('Stage Metrics Display', () => {
    it('displays content counts for each stage', () => {
      render(<CampaignJourneyVisualization journey={mockJourney} />)

      expect(screen.getByText('8 content')).toBeInTheDocument()
      expect(screen.getByText('6 content')).toBeInTheDocument()
      expect(screen.getByText('4 content')).toBeInTheDocument()
      expect(screen.getByText('0 content')).toBeInTheDocument()
    })

    it('formats impression numbers correctly', () => {
      render(<CampaignJourneyVisualization journey={mockJourney} />)

      expect(screen.getByText('75.0K')).toBeInTheDocument()
      expect(screen.getByText('40.0K')).toBeInTheDocument()
      expect(screen.getByText('10.0K')).toBeInTheDocument()
      expect(screen.getByText('0')).toBeInTheDocument()
    })

    it('displays engagement percentages', () => {
      render(<CampaignJourneyVisualization journey={mockJourney} />)

      expect(screen.getByText('3.8%')).toBeInTheDocument()
      expect(screen.getByText('5.2%')).toBeInTheDocument()
      expect(screen.getByText('6.8%')).toBeInTheDocument()
      expect(screen.getByText('0%')).toBeInTheDocument()
    })
  })

  describe('Channel Display', () => {
    it('shows channels for each stage', () => {
      render(<CampaignJourneyVisualization journey={mockJourney} />)

      // Awareness stage channels
      expect(screen.getByText('Blog')).toBeInTheDocument()
      expect(screen.getAllByText('Social Media')).toHaveLength(3) // appears in 3 stages
      expect(screen.getByText('Display Ads')).toBeInTheDocument()

      // Other channels
      expect(screen.getAllByText('Email')).toHaveLength(3) // appears in 3 stages
      expect(screen.getByText('Landing Pages')).toBeInTheDocument()
    })

    it('displays channel icons', () => {
      const { container } = render(<CampaignJourneyVisualization journey={mockJourney} />)

      // Check for presence of channel containers (icons are rendered via lucide-react)
      const channelContainers = container.querySelectorAll('.flex.items-center.gap-1.px-2.py-1')
      expect(channelContainers.length).toBeGreaterThan(0)
    })
  })

  describe('Interactive Features', () => {
    it('makes stage cards clickable', async () => {
      render(<CampaignJourneyVisualization journey={mockJourney} />)

      const awarenessCard = screen.getByText('Awareness').closest('.cursor-pointer')
      expect(awarenessCard).toBeInTheDocument()

      await user.click(awarenessCard!)
      
      // Should show expanded details
      await waitFor(() => {
        expect(screen.getByText('Content Pieces')).toBeInTheDocument()
        expect(screen.getByText('Impressions')).toBeInTheDocument()
        expect(screen.getByText('Engagement')).toBeInTheDocument()
      })
    })

    it('expands stage details when clicked', async () => {
      render(<CampaignJourneyVisualization journey={mockJourney} />)

      const considerationCard = screen.getByText('Consideration').closest('.cursor-pointer')
      await user.click(considerationCard!)

      await waitFor(() => {
        expect(screen.getByText('View Content')).toBeInTheDocument()
        expect(screen.getByText('View Analytics')).toBeInTheDocument()
      })
    })

    it('shows different action buttons based on stage status', async () => {
      render(<CampaignJourneyVisualization journey={mockJourney} />)

      // Click on pending stage (retention)
      const retentionCard = screen.getByText('Retention').closest('.cursor-pointer')
      await user.click(retentionCard!)

      await waitFor(() => {
        expect(screen.getByText('Start Stage')).toBeInTheDocument()
      })

      // Click on active stage (consideration)
      const considerationCard = screen.getByText('Consideration').closest('.cursor-pointer')
      await user.click(considerationCard!)

      await waitFor(() => {
        expect(screen.getByText('Pause Stage')).toBeInTheDocument()
      })
    })

    it('collapses expanded details when clicked again', async () => {
      render(<CampaignJourneyVisualization journey={mockJourney} />)

      const awarenessCard = screen.getByText('Awareness').closest('.cursor-pointer')
      
      // Expand
      await user.click(awarenessCard!)
      await waitFor(() => {
        expect(screen.getByText('Content Pieces')).toBeInTheDocument()
      })

      // Collapse
      await user.click(awarenessCard!)
      await waitFor(() => {
        expect(screen.queryByText('Content Pieces')).not.toBeInTheDocument()
      })
    })
  })

  describe('Journey Insights', () => {
    it('renders journey insights section', () => {
      render(<CampaignJourneyVisualization journey={mockJourney} />)

      expect(screen.getByText('Journey Insights')).toBeInTheDocument()
      expect(screen.getByText('Key metrics and recommendations for optimizing your customer journey')).toBeInTheDocument()
    })

    it('displays best performing stage', () => {
      render(<CampaignJourneyVisualization journey={mockJourney} />)

      expect(screen.getByText('Best Performing Stage')).toBeInTheDocument()
      expect(screen.getByText('6.8% engagement')).toBeInTheDocument()
    })

    it('shows optimization opportunities', () => {
      render(<CampaignJourneyVisualization journey={mockJourney} />)

      expect(screen.getByText('Optimization Opportunity')).toBeInTheDocument()
      expect(screen.getByText('Increase content variety')).toBeInTheDocument()
    })

    it('provides recommendations', () => {
      render(<CampaignJourneyVisualization journey={mockJourney} />)

      expect(screen.getByText('💡 Recommendation')).toBeInTheDocument()
      expect(screen.getByText(/Your consideration stage is performing well/)).toBeInTheDocument()
    })
  })

  describe('Progress Calculation', () => {
    it('calculates progress correctly with no completed stages', () => {
      const journeyWithNothingCompleted = {
        stages: mockJourney.stages.map(stage => ({ ...stage, status: 'pending' as const }))
      }

      render(<CampaignJourneyVisualization journey={journeyWithNothingCompleted} />)
      expect(screen.getByText('0%')).toBeInTheDocument()
    })

    it('calculates progress correctly with all stages completed', () => {
      const journeyAllCompleted = {
        stages: mockJourney.stages.map(stage => ({ ...stage, status: 'completed' as const }))
      }

      render(<CampaignJourneyVisualization journey={journeyAllCompleted} />)
      expect(screen.getByText('100%')).toBeInTheDocument()
    })

    it('handles single stage journey', () => {
      const singleStageJourney = {
        stages: [mockJourney.stages[0]]
      }

      render(<CampaignJourneyVisualization journey={singleStageJourney} />)
      expect(screen.getByText('100%')).toBeInTheDocument()
    })
  })

  describe('Number Formatting', () => {
    it('formats large numbers correctly', () => {
      const journeyWithLargeNumbers = {
        stages: [{
          ...mockJourney.stages[0],
          metrics: { impressions: 1500000, engagement: 8.7 }
        }]
      }

      render(<CampaignJourneyVisualization journey={journeyWithLargeNumbers} />)
      expect(screen.getByText('1.5M')).toBeInTheDocument()
    })

    it('formats small numbers correctly', () => {
      const journeyWithSmallNumbers = {
        stages: [{
          ...mockJourney.stages[0],
          metrics: { impressions: 500, engagement: 2.1 }
        }]
      }

      render(<CampaignJourneyVisualization journey={journeyWithSmallNumbers} />)
      expect(screen.getByText('500')).toBeInTheDocument()
    })
  })

  describe('Accessibility', () => {
    it('provides proper ARIA roles and labels', () => {
      render(<CampaignJourneyVisualization journey={mockJourney} />)

      const progressBar = screen.getByRole('progressbar')
      expect(progressBar).toBeInTheDocument()
    })

    it('supports keyboard navigation', async () => {
      render(<CampaignJourneyVisualization journey={mockJourney} />)

      const firstCard = screen.getByText('Awareness').closest('.cursor-pointer')
      expect(firstCard).toBeInTheDocument()

      // Should be focusable
      firstCard?.focus()
      expect(firstCard).toHaveFocus()
    })
  })

  describe('Edge Cases', () => {
    it('handles empty journey stages', () => {
      const emptyJourney = { stages: [] }
      
      render(<CampaignJourneyVisualization journey={emptyJourney} />)
      
      expect(screen.getByText('0%')).toBeInTheDocument()
      expect(screen.getByText('0 of 0 stages completed')).toBeInTheDocument()
    })

    it('handles stages with zero metrics', () => {
      const zeroMetricsJourney = {
        stages: [{
          ...mockJourney.stages[0],
          metrics: { impressions: 0, engagement: 0 }
        }]
      }

      render(<CampaignJourneyVisualization journey={zeroMetricsJourney} />)
      expect(screen.getByText('0')).toBeInTheDocument()
      expect(screen.getByText('0%')).toBeInTheDocument()
    })

    it('handles stages with empty channel arrays', () => {
      const noChannelsJourney = {
        stages: [{
          ...mockJourney.stages[0],
          channels: []
        }]
      }

      render(<CampaignJourneyVisualization journey={noChannelsJourney} />)
      expect(screen.getByText('Awareness')).toBeInTheDocument()
    })
  })
})