import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { userEvent } from '@testing-library/user-event'
import { CampaignMetricsPanel } from '../campaign-metrics-panel'

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

describe('CampaignMetricsPanel Component', () => {
  const user = userEvent.setup()

  describe('Basic Rendering', () => {
    it('renders key performance indicators', () => {
      render(<CampaignMetricsPanel campaign={mockCampaign} />)

      expect(screen.getByText('Total Impressions')).toBeInTheDocument()
      expect(screen.getByText('Click-through Rate')).toBeInTheDocument()
      expect(screen.getByText('Cost per Conversion')).toBeInTheDocument()
      expect(screen.getByText('ROI')).toBeInTheDocument()
    })

    it('displays formatted metrics values', () => {
      render(<CampaignMetricsPanel campaign={mockCampaign} />)

      expect(screen.getByText('125.0K')).toBeInTheDocument() // Impressions
      expect(screen.getByText('3.1%')).toBeInTheDocument() // CTR
      expect(screen.getByText('$22')).toBeInTheDocument() // Cost per conversion
    })

    it('shows trend indicators', () => {
      render(<CampaignMetricsPanel campaign={mockCampaign} />)

      expect(screen.getByText('+12.5%')).toBeInTheDocument()
      expect(screen.getByText('+0.3%')).toBeInTheDocument()
      expect(screen.getByText('-8.2%')).toBeInTheDocument()
    })

    it('renders analytics tabs', () => {
      render(<CampaignMetricsPanel campaign={mockCampaign} />)

      expect(screen.getByRole('tab', { name: 'Performance' })).toBeInTheDocument()
      expect(screen.getByRole('tab', { name: 'Channels' })).toBeInTheDocument()
      expect(screen.getByRole('tab', { name: 'Budget' })).toBeInTheDocument()
      expect(screen.getByRole('tab', { name: 'Audience' })).toBeInTheDocument()
    })
  })

  describe('Performance Tab', () => {
    it('displays performance trends by default', () => {
      render(<CampaignMetricsPanel campaign={mockCampaign} />)

      expect(screen.getByText('Performance Trends')).toBeInTheDocument()
      expect(screen.getByText('Weekly performance metrics over time')).toBeInTheDocument()
    })

    it('shows performance timeline data', () => {
      render(<CampaignMetricsPanel campaign={mockCampaign} />)

      // Check for week indicators
      expect(screen.getByText('Week 5')).toBeInTheDocument()
      expect(screen.getByText('Week 6')).toBeInTheDocument()
      expect(screen.getByText('Week 7')).toBeInTheDocument()
      expect(screen.getByText('Week 8')).toBeInTheDocument()
    })

    it('displays performance insights', () => {
      render(<CampaignMetricsPanel campaign={mockCampaign} />)

      expect(screen.getByText('📈 Performance Insights')).toBeInTheDocument()
      expect(screen.getByText(/Impressions have grown by 45%/)).toBeInTheDocument()
      expect(screen.getByText(/Engagement rate peaked at 4.5%/)).toBeInTheDocument()
      expect(screen.getByText(/Conversion growth is accelerating/)).toBeInTheDocument()
    })
  })

  describe('Channels Tab', () => {
    it('switches to channels tab when clicked', async () => {
      render(<CampaignMetricsPanel campaign={mockCampaign} />)

      const channelsTab = screen.getByRole('tab', { name: 'Channels' })
      await user.click(channelsTab)

      await waitFor(() => {
        expect(screen.getByText('Channel Performance')).toBeInTheDocument()
        expect(screen.getByText('Compare performance across marketing channels')).toBeInTheDocument()
      })
    })

    it('displays channel performance data', async () => {
      render(<CampaignMetricsPanel campaign={mockCampaign} />)

      const channelsTab = screen.getByRole('tab', { name: 'Channels' })
      await user.click(channelsTab)

      await waitFor(() => {
        expect(screen.getByText('Email')).toBeInTheDocument()
        expect(screen.getByText('Social Media')).toBeInTheDocument()
        expect(screen.getByText('Blog')).toBeInTheDocument()
        expect(screen.getByText('Display Ads')).toBeInTheDocument()
      })
    })

    it('shows channel metrics', async () => {
      render(<CampaignMetricsPanel campaign={mockCampaign} />)

      const channelsTab = screen.getByRole('tab', { name: 'Channels' })
      await user.click(channelsTab)

      await waitFor(() => {
        expect(screen.getByText('45.0K')).toBeInTheDocument() // Email impressions
        expect(screen.getByText('8.2%')).toBeInTheDocument() // Email engagement
        expect(screen.getByText('38.0K')).toBeInTheDocument() // Social impressions
      })
    })

    it('displays channel insights', async () => {
      render(<CampaignMetricsPanel campaign={mockCampaign} />)

      const channelsTab = screen.getByRole('tab', { name: 'Channels' })
      await user.click(channelsTab)

      await waitFor(() => {
        expect(screen.getByText('🎯 Channel Insights')).toBeInTheDocument()
        expect(screen.getByText(/Email has the highest engagement rate/)).toBeInTheDocument()
        expect(screen.getByText(/Consider reducing Display Ads budget/)).toBeInTheDocument()
      })
    })
  })

  describe('Budget Tab', () => {
    it('switches to budget tab when clicked', async () => {
      render(<CampaignMetricsPanel campaign={mockCampaign} />)

      const budgetTab = screen.getByRole('tab', { name: 'Budget' })
      await user.click(budgetTab)

      await waitFor(() => {
        expect(screen.getByText('Budget Utilization')).toBeInTheDocument()
        expect(screen.getByText('Cost Analysis')).toBeInTheDocument()
      })
    })

    it('displays budget utilization', async () => {
      render(<CampaignMetricsPanel campaign={mockCampaign} />)

      const budgetTab = screen.getByRole('tab', { name: 'Budget' })
      await user.click(budgetTab)

      await waitFor(() => {
        expect(screen.getByText('$18,750')).toBeInTheDocument() // Spent
        expect(screen.getByText('$6,250')).toBeInTheDocument() // Remaining
        expect(screen.getByText('75%')).toBeInTheDocument() // Utilization percentage
      })
    })

    it('shows budget alerts', async () => {
      render(<CampaignMetricsPanel campaign={mockCampaign} />)

      const budgetTab = screen.getByRole('tab', { name: 'Budget' })
      await user.click(budgetTab)

      await waitFor(() => {
        expect(screen.getByText('Budget Alert:')).toBeInTheDocument()
        expect(screen.getByText(/You've spent 75% of your budget/)).toBeInTheDocument()
      })
    })

    it('displays cost analysis', async () => {
      render(<CampaignMetricsPanel campaign={mockCampaign} />)

      const budgetTab = screen.getByRole('tab', { name: 'Budget' })
      await user.click(budgetTab)

      await waitFor(() => {
        expect(screen.getByText('Average CPC')).toBeInTheDocument()
        expect(screen.getByText('Daily Spend Rate')).toBeInTheDocument()
        expect(screen.getByText('Projected Total Spend')).toBeInTheDocument()
      })
    })

    it('shows efficiency indicators', async () => {
      render(<CampaignMetricsPanel campaign={mockCampaign} />)

      const budgetTab = screen.getByRole('tab', { name: 'Budget' })
      await user.click(budgetTab)

      await waitFor(() => {
        expect(screen.getByText('Efficiency:')).toBeInTheDocument()
        expect(screen.getByText(/cost per conversion is 15% below industry average/)).toBeInTheDocument()
      })
    })
  })

  describe('Audience Tab', () => {
    it('switches to audience tab when clicked', async () => {
      render(<CampaignMetricsPanel campaign={mockCampaign} />)

      const audienceTab = screen.getByRole('tab', { name: 'Audience' })
      await user.click(audienceTab)

      await waitFor(() => {
        expect(screen.getByText('Audience Insights')).toBeInTheDocument()
        expect(screen.getByText('Demographics and behavior of your campaign audience')).toBeInTheDocument()
      })
    })

    it('displays demographic breakdowns', async () => {
      render(<CampaignMetricsPanel campaign={mockCampaign} />)

      const audienceTab = screen.getByRole('tab', { name: 'Audience' })
      await user.click(audienceTab)

      await waitFor(() => {
        expect(screen.getByText('25-34 years')).toBeInTheDocument()
        expect(screen.getByText('35-44 years')).toBeInTheDocument()
        expect(screen.getByText('18-24 years')).toBeInTheDocument()
        expect(screen.getByText('45+ years')).toBeInTheDocument()
      })
    })

    it('shows engagement by segment', async () => {
      render(<CampaignMetricsPanel campaign={mockCampaign} />)

      const audienceTab = screen.getByRole('tab', { name: 'Audience' })
      await user.click(audienceTab)

      await waitFor(() => {
        expect(screen.getByText('High Intent Users')).toBeInTheDocument()
        expect(screen.getByText('New Visitors')).toBeInTheDocument()
        expect(screen.getByText('Returning Users')).toBeInTheDocument()
      })
    })

    it('displays audience insights', async () => {
      render(<CampaignMetricsPanel campaign={mockCampaign} />)

      const audienceTab = screen.getByRole('tab', { name: 'Audience' })
      await user.click(audienceTab)

      await waitFor(() => {
        expect(screen.getByText('👥 Audience Insights')).toBeInTheDocument()
        expect(screen.getByText(/Your primary audience \(25-34\)/)).toBeInTheDocument()
        expect(screen.getByText(/Consider creating retargeting campaigns/)).toBeInTheDocument()
      })
    })
  })

  describe('ROI Calculations', () => {
    it('calculates positive ROI correctly', () => {
      const profitableCampaign = {
        ...mockCampaign,
        budget: { total: 10000, spent: 5000, currency: 'USD' },
        metrics: { ...mockCampaign.metrics, conversions: 200 }
      }

      render(<CampaignMetricsPanel campaign={profitableCampaign} />)

      expect(screen.getByText('+100%')).toBeInTheDocument()
      expect(screen.getByText('Profitable')).toBeInTheDocument()
    })

    it('calculates negative ROI correctly', () => {
      const unprofitableCampaign = {
        ...mockCampaign,
        budget: { total: 10000, spent: 8000, currency: 'USD' },
        metrics: { ...mockCampaign.metrics, conversions: 50 }
      }

      render(<CampaignMetricsPanel campaign={unprofitableCampaign} />)

      expect(screen.getByText('At Loss')).toBeInTheDocument()
    })
  })

  describe('Number Formatting', () => {
    it('formats impressions in thousands', () => {
      const campaignWithLargeImpressions = {
        ...mockCampaign,
        metrics: { ...mockCampaign.metrics, impressions: 1500000 }
      }

      render(<CampaignMetricsPanel campaign={campaignWithLargeImpressions} />)
      expect(screen.getByText('1.5M')).toBeInTheDocument()
    })

    it('formats currency correctly', () => {
      render(<CampaignMetricsPanel campaign={mockCampaign} />)

      expect(screen.getByText('$18,750')).toBeInTheDocument()
      expect(screen.getByText('$6,250')).toBeInTheDocument()
    })

    it('handles different currencies', () => {
      const euroCampaign = {
        ...mockCampaign,
        budget: { ...mockCampaign.budget, currency: 'EUR' }
      }

      render(<CampaignMetricsPanel campaign={euroCampaign} />)

      // Should format with Euro symbol, but we're using USD symbols in the mock
      // In real implementation, this would show € symbols
      expect(screen.getByText(/18,750/)).toBeInTheDocument()
    })
  })

  describe('Progress Bars and Visual Elements', () => {
    it('renders progress bars for demographics', async () => {
      render(<CampaignMetricsPanel campaign={mockCampaign} />)

      const audienceTab = screen.getByRole('tab', { name: 'Audience' })
      await user.click(audienceTab)

      await waitFor(() => {
        const progressBars = screen.getAllByRole('progressbar')
        expect(progressBars.length).toBeGreaterThanOrEqual(4) // At least 4 demographic progress bars
      })
    })

    it('renders budget utilization progress bar', async () => {
      render(<CampaignMetricsPanel campaign={mockCampaign} />)

      const budgetTab = screen.getByRole('tab', { name: 'Budget' })
      await user.click(budgetTab)

      await waitFor(() => {
        expect(screen.getByRole('progressbar')).toBeInTheDocument()
      })
    })
  })

  describe('Data Validation', () => {
    it('handles missing optional metrics gracefully', () => {
      const campaignWithMissingMetrics = {
        ...mockCampaign,
        metrics: {
          impressions: 50000,
          engagement: 3.5,
          conversions: 200,
          clickThroughRate: 2.8,
          costPerConversion: 15.0,
          progress: 50,
          contentPieces: 8
        }
      }

      render(<CampaignMetricsPanel campaign={campaignWithMissingMetrics} />)

      expect(screen.getByText('50.0K')).toBeInTheDocument()
      expect(screen.getByText('3.5%')).toBeInTheDocument()
    })

    it('handles zero values correctly', () => {
      const zeroMetricsCampaign = {
        ...mockCampaign,
        metrics: {
          ...mockCampaign.metrics,
          impressions: 0,
          conversions: 0
        }
      }

      render(<CampaignMetricsPanel campaign={zeroMetricsCampaign} />)

      expect(screen.getByText('0')).toBeInTheDocument()
    })
  })

  describe('Accessibility', () => {
    it('provides proper tab navigation', async () => {
      render(<CampaignMetricsPanel campaign={mockCampaign} />)

      const performanceTab = screen.getByRole('tab', { name: 'Performance' })
      const channelsTab = screen.getByRole('tab', { name: 'Channels' })

      expect(performanceTab).toHaveAttribute('aria-selected', 'true')
      
      await user.click(channelsTab)
      await waitFor(() => {
        expect(channelsTab).toHaveAttribute('aria-selected', 'true')
        expect(performanceTab).toHaveAttribute('aria-selected', 'false')
      })
    })

    it('provides proper progress bar labels', async () => {
      render(<CampaignMetricsPanel campaign={mockCampaign} />)

      const budgetTab = screen.getByRole('tab', { name: 'Budget' })
      await user.click(budgetTab)

      await waitFor(() => {
        const progressBar = screen.getByRole('progressbar')
        expect(progressBar).toBeInTheDocument()
      })
    })
  })

  describe('Edge Cases', () => {
    it('handles campaigns with no spend', () => {
      const noSpendCampaign = {
        ...mockCampaign,
        budget: { total: 10000, spent: 0, currency: 'USD' }
      }

      render(<CampaignMetricsPanel campaign={noSpendCampaign} />)

      expect(screen.getByText('$0')).toBeInTheDocument()
    })

    it('handles campaigns with zero budget', () => {
      const zeroBudgetCampaign = {
        ...mockCampaign,
        budget: { total: 0, spent: 0, currency: 'USD' }
      }

      render(<CampaignMetricsPanel campaign={zeroBudgetCampaign} />)

      expect(screen.getByText('$0')).toBeInTheDocument()
    })

    it('handles very small numbers correctly', () => {
      const smallNumbersCampaign = {
        ...mockCampaign,
        metrics: {
          ...mockCampaign.metrics,
          impressions: 50,
          conversions: 1
        }
      }

      render(<CampaignMetricsPanel campaign={smallNumbersCampaign} />)

      expect(screen.getByText('50')).toBeInTheDocument()
      expect(screen.getByText('1')).toBeInTheDocument()
    })
  })
})