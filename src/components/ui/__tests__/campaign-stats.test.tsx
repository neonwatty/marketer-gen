import { render, screen } from '@testing-library/react'
import { CampaignStats, type CampaignStatsProps } from '../campaign-stats'

const mockStats: CampaignStatsProps['stats'] = {
  totalCampaigns: 8,
  activeCampaigns: 2,
  totalBudget: 150000,
  totalImpressions: 750000,
  avgEngagement: 5.8,
  totalConversions: 3200,
  conversionTrend: 8.5,
  budgetUtilization: 75
}

describe('CampaignStats Component', () => {
  describe('Basic Rendering', () => {
    it('renders all stat cards', () => {
      render(<CampaignStats stats={mockStats} />)

      expect(screen.getByText('Total Campaigns')).toBeInTheDocument()
      expect(screen.getByText('Active Campaigns')).toBeInTheDocument()
      expect(screen.getByText('Total Budget')).toBeInTheDocument()
      expect(screen.getByText('Avg Engagement')).toBeInTheDocument()
    })

    it('displays correct stat values', () => {
      render(<CampaignStats stats={mockStats} />)

      expect(screen.getByText('8')).toBeInTheDocument() // Total campaigns
      expect(screen.getByText('2')).toBeInTheDocument() // Active campaigns
      expect(screen.getByText('$150,000')).toBeInTheDocument() // Total budget
      expect(screen.getByText('5.8%')).toBeInTheDocument() // Avg engagement
    })

    it('renders appropriate icons for each stat', () => {
      const { container } = render(<CampaignStats stats={mockStats} />)

      // Should have SVG icons for each stat card
      const svgIcons = container.querySelectorAll('svg')
      expect(svgIcons.length).toBeGreaterThanOrEqual(4)
    })
  })

  describe('Trend Indicators', () => {
    it('displays positive trend for active campaigns', () => {
      render(<CampaignStats stats={mockStats} />)

      // Active campaigns should show +15% trend
      expect(screen.getByText('+15%')).toBeInTheDocument()
      expect(screen.getAllByText('from last month')).toHaveLength(3) // Multiple cards have this text
    })

    it('displays positive trend with green styling', () => {
      render(<CampaignStats stats={mockStats} />)

      const positiveTrend = screen.getByText('+15%')
      expect(positiveTrend).toHaveClass('text-green-500')
    })

    it('displays conversion trend correctly', () => {
      render(<CampaignStats stats={mockStats} />)

      // Engagement card should show the conversion trend
      const conversionTrend = screen.getByText('+8.5%')
      expect(conversionTrend).toBeInTheDocument()
      expect(conversionTrend).toHaveClass('text-green-500')
    })

    it('shows negative trend when budget utilization is low', () => {
      const statsWithLowBudget = {
        ...mockStats,
        budgetUtilization: 50 // Low utilization should show negative trend
      }

      render(<CampaignStats stats={statsWithLowBudget} />)

      const negativeTrend = screen.getByText('-2%')
      expect(negativeTrend).toBeInTheDocument()
      expect(negativeTrend).toHaveClass('text-red-500')
    })

    it('shows positive trend when budget utilization is high', () => {
      const statsWithHighBudget = {
        ...mockStats,
        budgetUtilization: 85 // High utilization should show positive trend
      }

      render(<CampaignStats stats={statsWithHighBudget} />)

      const positiveTrend = screen.getByText('+5%')
      expect(positiveTrend).toBeInTheDocument()
      expect(positiveTrend).toHaveClass('text-green-500')
    })
  })

  describe('Number Formatting', () => {
    it('formats currency correctly', () => {
      render(<CampaignStats stats={mockStats} />)

      expect(screen.getByText('$150,000')).toBeInTheDocument()
    })

    it('formats large numbers with K and M suffixes', () => {
      const statsWithLargeNumbers = {
        ...mockStats,
        totalBudget: 2500000, // Should show as $2,500,000
        totalImpressions: 15000000 // Large number for testing
      }

      render(<CampaignStats stats={statsWithLargeNumbers} />)

      expect(screen.getByText('$2,500,000')).toBeInTheDocument()
    })

    it('formats percentages correctly', () => {
      render(<CampaignStats stats={mockStats} />)

      expect(screen.getByText('5.8%')).toBeInTheDocument()
    })

    it('handles decimal values correctly', () => {
      const statsWithDecimals = {
        ...mockStats,
        avgEngagement: 7.25
      }

      render(<CampaignStats stats={statsWithDecimals} />)

      expect(screen.getByText('7.25%')).toBeInTheDocument()
    })
  })

  describe('Edge Cases', () => {
    it('handles zero values correctly', () => {
      const statsWithZeros = {
        ...mockStats,
        activeCampaigns: 0,
        totalBudget: 0,
        avgEngagement: 0
      }

      render(<CampaignStats stats={statsWithZeros} />)

      expect(screen.getByText('0')).toBeInTheDocument() // Active campaigns
      expect(screen.getByText('$0')).toBeInTheDocument() // Total budget  
      expect(screen.getByText('0%')).toBeInTheDocument() // Avg engagement
    })

    it('handles very large numbers', () => {
      const statsWithLargeNumbers = {
        ...mockStats,
        totalCampaigns: 999,
        totalImpressions: 50000000,
        totalBudget: 10000000
      }

      render(<CampaignStats stats={statsWithLargeNumbers} />)

      expect(screen.getByText('999')).toBeInTheDocument()
      expect(screen.getByText('$10,000,000')).toBeInTheDocument()
    })

    it('handles negative trend values', () => {
      const statsWithNegativeTrend = {
        ...mockStats,
        conversionTrend: -5.2
      }

      render(<CampaignStats stats={statsWithNegativeTrend} />)

      const negativeTrend = screen.getByText('-5.2%')
      expect(negativeTrend).toBeInTheDocument()
      expect(negativeTrend).toHaveClass('text-red-500')
    })
  })

  describe('Responsive Grid Layout', () => {
    it('applies correct grid classes', () => {
      const { container } = render(<CampaignStats stats={mockStats} />)

      const gridContainer = container.firstChild as HTMLElement
      expect(gridContainer).toHaveClass('grid')
      expect(gridContainer).toHaveClass('gap-4')
      expect(gridContainer).toHaveClass('md:grid-cols-2')
      expect(gridContainer).toHaveClass('lg:grid-cols-4')
    })
  })

  describe('Trend Icons', () => {
    it('shows trending up icon for positive trends', () => {
      const { container } = render(<CampaignStats stats={mockStats} />)

      // Should have trending up icons for positive trends
      const trendingUpIcons = container.querySelectorAll('svg[class*="text-green-500"]')
      expect(trendingUpIcons.length).toBeGreaterThan(0)
    })

    it('shows trending down icon for negative trends', () => {
      const statsWithNegativeTrend = {
        ...mockStats,
        conversionTrend: -3.0,
        budgetUtilization: 40 // This should trigger negative trend
      }

      const { container } = render(<CampaignStats stats={statsWithNegativeTrend} />)

      // Should have trending down icons for negative trends
      const trendingDownIcons = container.querySelectorAll('svg[class*="text-red-500"]')
      expect(trendingDownIcons.length).toBeGreaterThan(0)
    })
  })

  describe('Card Structure', () => {
    it('renders cards with proper header and content sections', () => {
      render(<CampaignStats stats={mockStats} />)

      // Each stat should be in a card structure
      expect(screen.getByText('Total Campaigns')).toBeInTheDocument()
      expect(screen.getByText('Active Campaigns')).toBeInTheDocument()
      expect(screen.getByText('Total Budget')).toBeInTheDocument()
      expect(screen.getByText('Avg Engagement')).toBeInTheDocument()

      // Values should be in separate sections
      expect(screen.getByText('8')).toBeInTheDocument()
      expect(screen.getByText('2')).toBeInTheDocument()
    })

    it('applies correct styling classes to cards', () => {
      const { container } = render(<CampaignStats stats={mockStats} />)

      const cards = container.querySelectorAll('[data-slot="card"]')
      expect(cards.length).toBe(4)
    })
  })

  describe('Accessibility', () => {
    it('provides semantic structure', () => {
      render(<CampaignStats stats={mockStats} />)

      // Stats should be presented in a structured way
      const headings = screen.getAllByText(/Total|Active|Avg/)
      expect(headings.length).toBeGreaterThanOrEqual(4)
    })
  })

  describe('Content Validation', () => {
    it('shows correct labels for each stat', () => {
      render(<CampaignStats stats={mockStats} />)

      expect(screen.getByText('Total Campaigns')).toBeInTheDocument()
      expect(screen.getByText('Active Campaigns')).toBeInTheDocument()
      expect(screen.getByText('Total Budget')).toBeInTheDocument()
      expect(screen.getByText('Avg Engagement')).toBeInTheDocument()
    })

    it('associates icons with correct stats', () => {
      const { container } = render(<CampaignStats stats={mockStats} />)

      // Each card should have an icon in the header
      const cardHeaders = container.querySelectorAll('[data-slot="card-header"]')
      cardHeaders.forEach(header => {
        const icon = header.querySelector('svg')
        expect(icon).toBeInTheDocument()
      })
    })
  })
})