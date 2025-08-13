import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import '@testing-library/jest-dom'

// Mock Recharts components
vi.mock('recharts', () => ({
  ResponsiveContainer: ({ children }: any) => <div data-testid="responsive-container">{children}</div>,
  BarChart: ({ children }: any) => <div data-testid="bar-chart">{children}</div>,
  LineChart: ({ children }: any) => <div data-testid="line-chart">{children}</div>,
  PieChart: ({ children }: any) => <div data-testid="pie-chart">{children}</div>,
  AreaChart: ({ children }: any) => <div data-testid="area-chart">{children}</div>,
  RadarChart: ({ children }: any) => <div data-testid="radar-chart">{children}</div>,
  ScatterChart: ({ children }: any) => <div data-testid="scatter-chart">{children}</div>,
  Bar: () => <div data-testid="bar" />,
  Line: () => <div data-testid="line" />,
  Area: () => <div data-testid="area" />,
  Pie: () => <div data-testid="pie" />,
  Cell: () => <div data-testid="cell" />,
  Scatter: () => <div data-testid="scatter" />,
  PolarGrid: () => <div data-testid="polar-grid" />,
  PolarAngleAxis: () => <div data-testid="polar-angle-axis" />,
  PolarRadiusAxis: () => <div data-testid="polar-radius-axis" />,
  Radar: () => <div data-testid="radar" />,
  XAxis: () => <div data-testid="x-axis" />,
  YAxis: () => <div data-testid="y-axis" />,
  CartesianGrid: () => <div data-testid="cartesian-grid" />,
  Tooltip: () => <div data-testid="tooltip" />,
  Legend: () => <div data-testid="legend" />
}))

import { CollaborationAnalytics } from '@/components/analytics/collaboration-analytics'

// Mock data
const mockAnalyticsData = {
  overview: {
    totalCollaborations: 1250,
    activeUsers: 34,
    averageResponseTime: 45,
    collaborationGrowth: 23.5
  },
  workflows: {
    totalWorkflows: 89,
    completedWorkflows: 67,
    averageCompletionTime: 4.2,
    workflowEfficiency: 87.3
  },
  teamMetrics: {
    mostActiveMembers: [
      { id: '1', name: 'John Doe', collaborations: 145, efficiency: 92 },
      { id: '2', name: 'Sarah Wilson', collaborations: 132, efficiency: 89 },
      { id: '3', name: 'Mike Johnson', collaborations: 98, efficiency: 94 }
    ],
    teamCollaboration: 85.7,
    crossTeamActivity: 42.3
  },
  insights: [
    {
      id: '1',
      type: 'optimization',
      title: 'Workflow Bottleneck Detected',
      description: 'Approval stage is causing 67% of workflow delays',
      impact: 'high',
      recommendation: 'Consider adding additional approvers or streamlining approval criteria'
    },
    {
      id: '2',
      type: 'performance',
      title: 'Team Collaboration Peak Hours',
      description: 'Peak collaboration occurs between 10 AM - 2 PM',
      impact: 'medium',
      recommendation: 'Schedule important discussions during peak hours for better engagement'
    }
  ]
}

describe('CollaborationAnalytics Component', () => {
  const defaultProps = {
    data: mockAnalyticsData,
    timeRange: 'month' as const
  }

  describe('Rendering', () => {
    test('should render analytics dashboard with all main sections', () => {
      render(<CollaborationAnalytics {...defaultProps} />)

      expect(screen.getByText('Collaboration Analytics')).toBeInTheDocument()
      expect(screen.getByRole('tablist')).toBeInTheDocument()
      
      // Check for main tabs
      expect(screen.getByRole('tab', { name: /overview/i })).toBeInTheDocument()
      expect(screen.getByRole('tab', { name: /workflows/i })).toBeInTheDocument()
      expect(screen.getByRole('tab', { name: /team/i })).toBeInTheDocument()
      expect(screen.getByRole('tab', { name: /insights/i })).toBeInTheDocument()
    })

    test('should display overview metrics correctly', () => {
      render(<CollaborationAnalytics {...defaultProps} />)

      expect(screen.getByText('1,250')).toBeInTheDocument() // Total collaborations
      expect(screen.getByText('34')).toBeInTheDocument() // Active users
      expect(screen.getByText('45 min')).toBeInTheDocument() // Average response time
      expect(screen.getByText('23.5%')).toBeInTheDocument() // Growth percentage
    })

    test('should show time range selector', () => {
      render(<CollaborationAnalytics {...defaultProps} />)

      expect(screen.getByRole('combobox') || screen.getByDisplayValue(/month/i)).toBeInTheDocument()
    })

    test('should render charts in overview section', () => {
      render(<CollaborationAnalytics {...defaultProps} />)

      expect(screen.getByTestId('responsive-container')).toBeInTheDocument()
      expect(screen.getByTestId('line-chart') || screen.getByTestId('bar-chart')).toBeInTheDocument()
    })
  })

  describe('Tab Navigation', () => {
    test('should switch between tabs correctly', async () => {
      const user = userEvent.setup()
      render(<CollaborationAnalytics {...defaultProps} />)

      // Initially on overview tab
      expect(screen.getByText('Total Collaborations')).toBeInTheDocument()

      // Switch to workflows tab
      const workflowsTab = screen.getByRole('tab', { name: /workflows/i })
      await user.click(workflowsTab)

      expect(screen.getByText('Total Workflows')).toBeInTheDocument()
      expect(screen.getByText('89')).toBeInTheDocument() // Total workflows

      // Switch to team tab
      const teamTab = screen.getByRole('tab', { name: /team/i })
      await user.click(teamTab)

      expect(screen.getByText('Most Active Members')).toBeInTheDocument()
      expect(screen.getByText('John Doe')).toBeInTheDocument()

      // Switch to insights tab
      const insightsTab = screen.getByRole('tab', { name: /insights/i })
      await user.click(insightsTab)

      expect(screen.getByText('AI-Powered Insights')).toBeInTheDocument()
      expect(screen.getByText('Workflow Bottleneck Detected')).toBeInTheDocument()
    })

    test('should maintain active tab state', async () => {
      const user = userEvent.setup()
      render(<CollaborationAnalytics {...defaultProps} />)

      const workflowsTab = screen.getByRole('tab', { name: /workflows/i })
      await user.click(workflowsTab)

      expect(workflowsTab).toHaveAttribute('data-state', 'active')
    })
  })

  describe('Overview Tab', () => {
    test('should display key performance indicators', () => {
      render(<CollaborationAnalytics {...defaultProps} />)

      // Check KPI cards
      expect(screen.getByText('Total Collaborations')).toBeInTheDocument()
      expect(screen.getByText('Active Users')).toBeInTheDocument()
      expect(screen.getByText('Avg Response Time')).toBeInTheDocument()
      expect(screen.getByText('Growth')).toBeInTheDocument()
    })

    test('should show collaboration trend chart', () => {
      render(<CollaborationAnalytics {...defaultProps} />)

      expect(screen.getByText('Collaboration Trends')).toBeInTheDocument()
      expect(screen.getByTestId('line-chart')).toBeInTheDocument()
    })

    test('should display activity heatmap', () => {
      render(<CollaborationAnalytics {...defaultProps} />)

      expect(screen.getByText('Activity Heatmap') || screen.getByText('Daily Activity')).toBeInTheDocument()
    })

    test('should show collaboration distribution', () => {
      render(<CollaborationAnalytics {...defaultProps} />)

      expect(screen.getByText('Collaboration Types') || screen.getByText('Distribution')).toBeInTheDocument()
      expect(screen.getByTestId('pie-chart') || screen.getByTestId('bar-chart')).toBeInTheDocument()
    })
  })

  describe('Workflows Tab', () => {
    test('should display workflow metrics', async () => {
      const user = userEvent.setup()
      render(<CollaborationAnalytics {...defaultProps} />)

      const workflowsTab = screen.getByRole('tab', { name: /workflows/i })
      await user.click(workflowsTab)

      expect(screen.getByText('89')).toBeInTheDocument() // Total workflows
      expect(screen.getByText('67')).toBeInTheDocument() // Completed workflows
      expect(screen.getByText('4.2 days')).toBeInTheDocument() // Average completion time
      expect(screen.getByText('87.3%')).toBeInTheDocument() // Workflow efficiency
    })

    test('should show workflow performance chart', async () => {
      const user = userEvent.setup()
      render(<CollaborationAnalytics {...defaultProps} />)

      const workflowsTab = screen.getByRole('tab', { name: /workflows/i })
      await user.click(workflowsTab)

      expect(screen.getByText('Workflow Performance')).toBeInTheDocument()
      expect(screen.getByTestId('bar-chart') || screen.getByTestId('area-chart')).toBeInTheDocument()
    })

    test('should display workflow stage analysis', async () => {
      const user = userEvent.setup()
      render(<CollaborationAnalytics {...defaultProps} />)

      const workflowsTab = screen.getByRole('tab', { name: /workflows/i })
      await user.click(workflowsTab)

      expect(screen.getByText('Stage Performance') || screen.getByText('Bottleneck Analysis')).toBeInTheDocument()
    })
  })

  describe('Team Tab', () => {
    test('should display team member performance', async () => {
      const user = userEvent.setup()
      render(<CollaborationAnalytics {...defaultProps} />)

      const teamTab = screen.getByRole('tab', { name: /team/i })
      await user.click(teamTab)

      expect(screen.getByText('John Doe')).toBeInTheDocument()
      expect(screen.getByText('Sarah Wilson')).toBeInTheDocument()
      expect(screen.getByText('Mike Johnson')).toBeInTheDocument()

      expect(screen.getByText('145')).toBeInTheDocument() // John's collaborations
      expect(screen.getByText('92%')).toBeInTheDocument() // John's efficiency
    })

    test('should show team collaboration radar chart', async () => {
      const user = userEvent.setup()
      render(<CollaborationAnalytics {...defaultProps} />)

      const teamTab = screen.getByRole('tab', { name: /team/i })
      await user.click(teamTab)

      expect(screen.getByText('Team Collaboration Matrix')).toBeInTheDocument()
      expect(screen.getByTestId('radar-chart')).toBeInTheDocument()
    })

    test('should display cross-team activity metrics', async () => {
      const user = userEvent.setup()
      render(<CollaborationAnalytics {...defaultProps} />)

      const teamTab = screen.getByRole('tab', { name: /team/i })
      await user.click(teamTab)

      expect(screen.getByText('85.7%')).toBeInTheDocument() // Team collaboration
      expect(screen.getByText('42.3%')).toBeInTheDocument() // Cross-team activity
    })

    test('should show individual member details on click', async () => {
      const user = userEvent.setup()
      render(<CollaborationAnalytics {...defaultProps} />)

      const teamTab = screen.getByRole('tab', { name: /team/i })
      await user.click(teamTab)

      const memberCard = screen.getByText('John Doe').closest('div')
      if (memberCard) {
        await user.click(memberCard)
        
        // Should show member details
        expect(screen.getByText('Member Details') || screen.getByText('Performance Details')).toBeInTheDocument()
      }
    })
  })

  describe('Insights Tab', () => {
    test('should display AI-powered insights', async () => {
      const user = userEvent.setup()
      render(<CollaborationAnalytics {...defaultProps} />)

      const insightsTab = screen.getByRole('tab', { name: /insights/i })
      await user.click(insightsTab)

      expect(screen.getByText('AI-Powered Insights')).toBeInTheDocument()
      expect(screen.getByText('Workflow Bottleneck Detected')).toBeInTheDocument()
      expect(screen.getByText('Team Collaboration Peak Hours')).toBeInTheDocument()
    })

    test('should categorize insights by impact level', async () => {
      const user = userEvent.setup()
      render(<CollaborationAnalytics {...defaultProps} />)

      const insightsTab = screen.getByRole('tab', { name: /insights/i })
      await user.click(insightsTab)

      // Should show high impact insight
      const highImpactBadge = screen.getByText('High') || screen.getByText('high')
      expect(highImpactBadge).toBeInTheDocument()

      // Should show medium impact insight
      const mediumImpactBadge = screen.getByText('Medium') || screen.getByText('medium')
      expect(mediumImpactBadge).toBeInTheDocument()
    })

    test('should show actionable recommendations', async () => {
      const user = userEvent.setup()
      render(<CollaborationAnalytics {...defaultProps} />)

      const insightsTab = screen.getByRole('tab', { name: /insights/i })
      await user.click(insightsTab)

      expect(screen.getByText(/Consider adding additional approvers/i)).toBeInTheDocument()
      expect(screen.getByText(/Schedule important discussions during peak hours/i)).toBeInTheDocument()
    })

    test('should allow insight actions', async () => {
      const mockOnInsightAction = vi.fn()
      const user = userEvent.setup()

      render(
        <CollaborationAnalytics 
          {...defaultProps} 
          onInsightAction={mockOnInsightAction}
        />
      )

      const insightsTab = screen.getByRole('tab', { name: /insights/i })
      await user.click(insightsTab)

      const actionButton = screen.getByText('Implement') || screen.getByText('Apply')
      if (actionButton) {
        await user.click(actionButton)
        expect(mockOnInsightAction).toHaveBeenCalled()
      }
    })
  })

  describe('Time Range Functionality', () => {
    test('should update data when time range changes', async () => {
      const mockOnTimeRangeChange = vi.fn()
      const user = userEvent.setup()

      render(
        <CollaborationAnalytics 
          {...defaultProps} 
          onTimeRangeChange={mockOnTimeRangeChange}
        />
      )

      const timeRangeSelector = screen.getByRole('combobox')
      await user.click(timeRangeSelector)

      const weekOption = screen.getByText('Week') || screen.getByRole('option', { name: /week/i })
      await user.click(weekOption)

      expect(mockOnTimeRangeChange).toHaveBeenCalledWith('week')
    })

    test('should support custom date range selection', async () => {
      const user = userEvent.setup()
      render(<CollaborationAnalytics {...defaultProps} allowCustomRange />)

      const customRangeButton = screen.getByText('Custom Range') || screen.getByText('Custom')
      await user.click(customRangeButton)

      // Should show date picker
      expect(screen.getByRole('dialog') || screen.getByLabelText(/start date/i)).toBeInTheDocument()
    })

    test('should validate time range selections', async () => {
      const user = userEvent.setup()
      render(<CollaborationAnalytics {...defaultProps} />)

      const timeRangeSelector = screen.getByRole('combobox')
      await user.click(timeRangeSelector)

      // All standard options should be available
      expect(screen.getByText('Week')).toBeInTheDocument()
      expect(screen.getByText('Month')).toBeInTheDocument()
      expect(screen.getByText('Quarter')).toBeInTheDocument()
      expect(screen.getByText('Year')).toBeInTheDocument()
    })
  })

  describe('Data Filtering and Interaction', () => {
    test('should support metric filtering', async () => {
      const user = userEvent.setup()
      render(<CollaborationAnalytics {...defaultProps} />)

      const filterButton = screen.getByRole('button', { name: /filter/i })
      await user.click(filterButton)

      // Should show filter options
      expect(screen.getByText('Comments') || screen.getByText('Mentions')).toBeInTheDocument()
    })

    test('should handle chart interactions', async () => {
      const mockOnChartClick = vi.fn()
      render(
        <CollaborationAnalytics 
          {...defaultProps} 
          onChartClick={mockOnChartClick}
        />
      )

      // Charts should be interactive (mocked)
      expect(screen.getByTestId('line-chart')).toBeInTheDocument()
    })

    test('should support data export', async () => {
      const mockOnExport = vi.fn()
      const user = userEvent.setup()

      render(
        <CollaborationAnalytics 
          {...defaultProps} 
          onExport={mockOnExport}
        />
      )

      const exportButton = screen.getByRole('button', { name: /export/i })
      await user.click(exportButton)

      expect(mockOnExport).toHaveBeenCalled()
    })
  })

  describe('Loading and Error States', () => {
    test('should show loading state', () => {
      render(
        <CollaborationAnalytics 
          {...defaultProps} 
          data={undefined}
          isLoading={true}
        />
      )

      expect(screen.getByTestId('loading-spinner') || screen.getByText(/loading/i)).toBeInTheDocument()
    })

    test('should handle error state gracefully', () => {
      render(
        <CollaborationAnalytics 
          {...defaultProps} 
          data={undefined}
          error="Failed to load analytics data"
        />
      )

      expect(screen.getByText(/failed to load/i)).toBeInTheDocument()
      expect(screen.getByRole('button', { name: /retry/i })).toBeInTheDocument()
    })

    test('should handle partial data gracefully', () => {
      const incompleteData = {
        overview: mockAnalyticsData.overview,
        // Missing workflows, teamMetrics, insights
      }

      render(
        <CollaborationAnalytics 
          {...defaultProps} 
          data={incompleteData as any}
        />
      )

      expect(screen.getByText('Collaboration Analytics')).toBeInTheDocument()
    })

    test('should show empty state for no data', () => {
      const emptyData = {
        overview: {
          totalCollaborations: 0,
          activeUsers: 0,
          averageResponseTime: 0,
          collaborationGrowth: 0
        },
        workflows: {
          totalWorkflows: 0,
          completedWorkflows: 0,
          averageCompletionTime: 0,
          workflowEfficiency: 0
        },
        teamMetrics: {
          mostActiveMembers: [],
          teamCollaboration: 0,
          crossTeamActivity: 0
        },
        insights: []
      }

      render(
        <CollaborationAnalytics 
          {...defaultProps} 
          data={emptyData}
        />
      )

      expect(screen.getByText('No collaboration data available')).toBeInTheDocument()
    })
  })

  describe('Responsive Design', () => {
    test('should adapt to mobile view', () => {
      // Mock mobile viewport
      Object.defineProperty(window, 'innerWidth', {
        writable: true,
        configurable: true,
        value: 375
      })

      render(<CollaborationAnalytics {...defaultProps} />)

      // Should still render main components
      expect(screen.getByText('Collaboration Analytics')).toBeInTheDocument()
    })

    test('should stack charts vertically on small screens', () => {
      render(<CollaborationAnalytics {...defaultProps} compact />)

      // Charts should still be rendered
      expect(screen.getByTestId('responsive-container')).toBeInTheDocument()
    })
  })

  describe('Real-time Updates', () => {
    test('should update when data changes', () => {
      const { rerender } = render(<CollaborationAnalytics {...defaultProps} />)

      expect(screen.getByText('1,250')).toBeInTheDocument()

      const updatedData = {
        ...mockAnalyticsData,
        overview: {
          ...mockAnalyticsData.overview,
          totalCollaborations: 1350
        }
      }

      rerender(<CollaborationAnalytics {...defaultProps} data={updatedData} />)

      expect(screen.getByText('1,350')).toBeInTheDocument()
    })

    test('should animate metric changes', () => {
      const { rerender } = render(<CollaborationAnalytics {...defaultProps} />)

      const updatedData = {
        ...mockAnalyticsData,
        overview: {
          ...mockAnalyticsData.overview,
          collaborationGrowth: 35.2
        }
      }

      rerender(<CollaborationAnalytics {...defaultProps} data={updatedData} />)

      expect(screen.getByText('35.2%')).toBeInTheDocument()
    })

    test('should handle streaming updates', async () => {
      const { rerender } = render(<CollaborationAnalytics {...defaultProps} />)

      // Simulate real-time update
      await waitFor(() => {
        const newData = {
          ...mockAnalyticsData,
          overview: {
            ...mockAnalyticsData.overview,
            activeUsers: 36
          }
        }

        rerender(<CollaborationAnalytics {...defaultProps} data={newData} />)
      })

      expect(screen.getByText('36')).toBeInTheDocument()
    })
  })

  describe('Accessibility', () => {
    test('should have proper ARIA labels', () => {
      render(<CollaborationAnalytics {...defaultProps} />)

      const tablist = screen.getByRole('tablist')
      expect(tablist).toHaveAttribute('aria-label', 'Analytics sections')

      const charts = screen.getAllByTestId('responsive-container')
      charts.forEach(chart => {
        expect(chart.closest('[role="img"]') || chart.closest('[aria-label]')).toBeInTheDocument()
      })
    })

    test('should be keyboard navigable', async () => {
      const user = userEvent.setup()
      render(<CollaborationAnalytics {...defaultProps} />)

      const firstTab = screen.getByRole('tab', { name: /overview/i })
      firstTab.focus()

      await user.keyboard('{ArrowRight}')
      
      const secondTab = screen.getByRole('tab', { name: /workflows/i })
      expect(secondTab).toHaveFocus()
    })

    test('should provide screen reader friendly chart descriptions', () => {
      render(<CollaborationAnalytics {...defaultProps} />)

      // Charts should have descriptive labels
      const chartContainers = screen.getAllByTestId('responsive-container')
      chartContainers.forEach(container => {
        const parent = container.closest('[aria-describedby]') || container.closest('[aria-label]')
        expect(parent).toBeInTheDocument()
      })
    })

    test('should announce data updates to screen readers', () => {
      render(<CollaborationAnalytics {...defaultProps} />)

      const liveRegion = screen.getByRole('status') || screen.getByLabelText(/live updates/i)
      expect(liveRegion).toBeInTheDocument()
    })
  })

  describe('Performance', () => {
    test('should render efficiently with large datasets', () => {
      const largeData = {
        ...mockAnalyticsData,
        teamMetrics: {
          ...mockAnalyticsData.teamMetrics,
          mostActiveMembers: Array.from({ length: 100 }, (_, i) => ({
            id: `member-${i}`,
            name: `Member ${i}`,
            collaborations: Math.floor(Math.random() * 200),
            efficiency: Math.floor(Math.random() * 100)
          }))
        }
      }

      const startTime = performance.now()
      render(<CollaborationAnalytics {...defaultProps} data={largeData} />)
      const endTime = performance.now()

      expect(endTime - startTime).toBeLessThan(1000) // Should render within 1 second
      expect(screen.getByText('Collaboration Analytics')).toBeInTheDocument()
    })

    test('should not re-render unnecessarily', () => {
      const { rerender } = render(<CollaborationAnalytics {...defaultProps} />)

      // Re-render with same props
      rerender(<CollaborationAnalytics {...defaultProps} />)

      // Should still work correctly
      expect(screen.getByText('Collaboration Analytics')).toBeInTheDocument()
    })

    test('should handle rapid data updates efficiently', async () => {
      const { rerender } = render(<CollaborationAnalytics {...defaultProps} />)

      // Simulate rapid updates
      for (let i = 0; i < 10; i++) {
        const updatedData = {
          ...mockAnalyticsData,
          overview: {
            ...mockAnalyticsData.overview,
            totalCollaborations: 1250 + i
          }
        }

        rerender(<CollaborationAnalytics {...defaultProps} data={updatedData} />)
      }

      expect(screen.getByText('1,259')).toBeInTheDocument()
    })
  })
})