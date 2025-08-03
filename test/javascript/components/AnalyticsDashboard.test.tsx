import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { axe, toHaveNoViolations } from 'jest-axe';

expect.extend(toHaveNoViolations);

// Mock analytics dashboard components that don't exist yet - will fail initially (TDD)
const AnalyticsDashboard = ({ 
  data, 
  timeRange, 
  onTimeRangeChange,
  realTime = false,
  customizable = false,
  ...props 
}: any) => {
  throw new Error('AnalyticsDashboard component not implemented yet');
};

const InteractiveChart = ({ 
  type, 
  data, 
  config,
  onDataPointClick,
  responsive = true,
  ...props 
}: any) => {
  throw new Error('InteractiveChart component not implemented yet');
};

const MetricCard = ({ 
  title, 
  value, 
  trend,
  comparison,
  loading = false,
  ...props 
}: any) => {
  throw new Error('MetricCard component not implemented yet');
};

const TimeRangePicker = ({ 
  value, 
  onChange,
  presets = [],
  customRange = true,
  ...props 
}: any) => {
  throw new Error('TimeRangePicker component not implemented yet');
};

const DataTable = ({ 
  data, 
  columns,
  sortable = true,
  filterable = true,
  exportable = false,
  ...props 
}: any) => {
  throw new Error('DataTable component not implemented yet');
};

const RealtimeIndicator = ({ 
  active, 
  lastUpdate,
  updateInterval = 30000,
  ...props 
}: any) => {
  throw new Error('RealtimeIndicator component not implemented yet');
};

describe('Analytics Dashboard', () => {
  const mockAnalyticsData = {
    metrics: {
      totalCampaigns: { value: 24, trend: 12.5, comparison: 'vs last month' },
      activeUsers: { value: 1250, trend: -3.2, comparison: 'vs last week' },
      conversions: { value: 89, trend: 8.7, comparison: 'vs last month' },
      revenue: { value: 45600, trend: 15.3, comparison: 'vs last month' }
    },
    charts: {
      campaignPerformance: {
        type: 'line',
        data: [
          { date: '2024-10-01', impressions: 12500, clicks: 350, conversions: 23 },
          { date: '2024-10-02', impressions: 13200, clicks: 380, conversions: 28 },
          { date: '2024-10-03', impressions: 11800, clicks: 340, conversions: 19 }
        ]
      },
      channelDistribution: {
        type: 'pie',
        data: [
          { channel: 'Email', value: 35, color: '#007bff' },
          { channel: 'Social Media', value: 28, color: '#28a745' },
          { channel: 'Paid Ads', value: 22, color: '#ffc107' },
          { channel: 'Organic', value: 15, color: '#6c757d' }
        ]
      },
      conversionFunnel: {
        type: 'funnel',
        data: [
          { stage: 'Awareness', value: 10000, percentage: 100 },
          { stage: 'Interest', value: 3500, percentage: 35 },
          { stage: 'Consideration', value: 1200, percentage: 12 },
          { stage: 'Purchase', value: 280, percentage: 2.8 }
        ]
      }
    },
    tableData: [
      { 
        campaign: 'Q4 Product Launch', 
        impressions: 25000, 
        clicks: 750, 
        ctr: 3.0, 
        conversions: 45, 
        cpa: '$50.25' 
      },
      { 
        campaign: 'Holiday Campaign', 
        impressions: 18500, 
        clicks: 420, 
        ctr: 2.27, 
        conversions: 28, 
        cpa: '$38.50' 
      }
    ]
  };

  describe('Dashboard Layout', () => {
    it('should render dashboard with all sections', () => {
      render(
        <AnalyticsDashboard 
          data={mockAnalyticsData}
          timeRange={{ start: '2024-10-01', end: '2024-10-31' }}
        />
      );
      
      expect(screen.getByTestId('metrics-section')).toBeInTheDocument();
      expect(screen.getByTestId('charts-section')).toBeInTheDocument();
      expect(screen.getByTestId('data-table-section')).toBeInTheDocument();
    });

    it('should display key metrics cards', () => {
      render(
        <AnalyticsDashboard 
          data={mockAnalyticsData}
          timeRange={{ start: '2024-10-01', end: '2024-10-31' }}
        />
      );
      
      expect(screen.getByText('Total Campaigns')).toBeInTheDocument();
      expect(screen.getByText('24')).toBeInTheDocument();
      expect(screen.getByText('Active Users')).toBeInTheDocument();
      expect(screen.getByText('1,250')).toBeInTheDocument();
      expect(screen.getByText('Conversions')).toBeInTheDocument();
      expect(screen.getByText('89')).toBeInTheDocument();
      expect(screen.getByText('Revenue')).toBeInTheDocument();
      expect(screen.getByText('$45,600')).toBeInTheDocument();
    });

    it('should support customizable layout', async () => {
      render(
        <AnalyticsDashboard 
          data={mockAnalyticsData}
          timeRange={{ start: '2024-10-01', end: '2024-10-31' }}
          customizable={true}
        />
      );
      
      const customizeButton = screen.getByRole('button', { name: /customize dashboard/i });
      await userEvent.click(customizeButton);
      
      expect(screen.getByText('Drag to rearrange widgets')).toBeInTheDocument();
      expect(screen.getAllByTestId('drag-handle')).toHaveLength(4); // 4 metric cards
    });

    it('should save layout preferences', async () => {
      const mockOnLayoutChange = jest.fn();
      
      render(
        <AnalyticsDashboard 
          data={mockAnalyticsData}
          timeRange={{ start: '2024-10-01', end: '2024-10-31' }}
          customizable={true}
          onLayoutChange={mockOnLayoutChange}
        />
      );
      
      const customizeButton = screen.getByRole('button', { name: /customize dashboard/i });
      await userEvent.click(customizeButton);
      
      // Simulate drag and drop (simplified)
      const firstWidget = screen.getAllByTestId('dashboard-widget')[0];
      const secondWidget = screen.getAllByTestId('dashboard-widget')[1];
      
      fireEvent.dragStart(firstWidget);
      fireEvent.dragOver(secondWidget);
      fireEvent.drop(secondWidget);
      
      expect(mockOnLayoutChange).toHaveBeenCalled();
    });
  });

  describe('Interactive Charts', () => {
    it('should render line chart with data', () => {
      render(
        <InteractiveChart 
          type="line"
          data={mockAnalyticsData.charts.campaignPerformance.data}
          config={{ xAxis: 'date', yAxis: 'impressions' }}
        />
      );
      
      expect(screen.getByTestId('line-chart')).toBeInTheDocument();
      expect(screen.getByText('Oct 1')).toBeInTheDocument();
      expect(screen.getByText('Oct 2')).toBeInTheDocument();
      expect(screen.getByText('Oct 3')).toBeInTheDocument();
    });

    it('should support chart interactions', async () => {
      const mockOnDataPointClick = jest.fn();
      
      render(
        <InteractiveChart 
          type="line"
          data={mockAnalyticsData.charts.campaignPerformance.data}
          onDataPointClick={mockOnDataPointClick}
        />
      );
      
      const dataPoint = screen.getByTestId('data-point-0');
      await userEvent.click(dataPoint);
      
      expect(mockOnDataPointClick).toHaveBeenCalledWith({
        date: '2024-10-01',
        impressions: 12500,
        clicks: 350,
        conversions: 23
      });
    });

    it('should show interactive tooltips', async () => {
      render(
        <InteractiveChart 
          type="line"
          data={mockAnalyticsData.charts.campaignPerformance.data}
          showTooltips={true}
        />
      );
      
      const dataPoint = screen.getByTestId('data-point-0');
      await userEvent.hover(dataPoint);
      
      await waitFor(() => {
        expect(screen.getByTestId('chart-tooltip')).toBeInTheDocument();
        expect(screen.getByText('12,500 impressions')).toBeInTheDocument();
        expect(screen.getByText('350 clicks')).toBeInTheDocument();
      });
    });

    it('should support zoom and pan functionality', async () => {
      render(
        <InteractiveChart 
          type="line"
          data={mockAnalyticsData.charts.campaignPerformance.data}
          zoomable={true}
          pannable={true}
        />
      );
      
      const chart = screen.getByTestId('line-chart');
      
      // Simulate wheel event for zoom
      fireEvent.wheel(chart, { deltaY: -100 });
      expect(screen.getByTestId('zoom-controls')).toBeInTheDocument();
      
      // Simulate drag for pan
      fireEvent.mouseDown(chart, { clientX: 100, clientY: 100 });
      fireEvent.mouseMove(chart, { clientX: 150, clientY: 100 });
      fireEvent.mouseUp(chart);
      
      expect(screen.getByTestId('pan-indicator')).toBeInTheDocument();
    });

    it('should render pie chart with segments', () => {
      render(
        <InteractiveChart 
          type="pie"
          data={mockAnalyticsData.charts.channelDistribution.data}
        />
      );
      
      expect(screen.getByTestId('pie-chart')).toBeInTheDocument();
      
      mockAnalyticsData.charts.channelDistribution.data.forEach(segment => {
        expect(screen.getByText(segment.channel)).toBeInTheDocument();
        expect(screen.getByText(`${segment.value}%`)).toBeInTheDocument();
      });
    });

    it('should support chart type switching', async () => {
      const { rerender } = render(
        <InteractiveChart 
          type="line"
          data={mockAnalyticsData.charts.campaignPerformance.data}
          allowTypeSwitch={true}
        />
      );
      
      const typeSelector = screen.getByLabelText(/chart type/i);
      await userEvent.selectOptions(typeSelector, 'bar');
      
      rerender(
        <InteractiveChart 
          type="bar"
          data={mockAnalyticsData.charts.campaignPerformance.data}
          allowTypeSwitch={true}
        />
      );
      
      expect(screen.getByTestId('bar-chart')).toBeInTheDocument();
    });

    it('should export chart data', async () => {
      const mockOnExport = jest.fn();
      
      render(
        <InteractiveChart 
          type="line"
          data={mockAnalyticsData.charts.campaignPerformance.data}
          exportable={true}
          onExport={mockOnExport}
        />
      );
      
      const exportButton = screen.getByRole('button', { name: /export chart/i });
      await userEvent.click(exportButton);
      
      expect(screen.getByText('PNG')).toBeInTheDocument();
      expect(screen.getByText('SVG')).toBeInTheDocument();
      expect(screen.getByText('CSV')).toBeInTheDocument();
      
      await userEvent.click(screen.getByText('PNG'));
      expect(mockOnExport).toHaveBeenCalledWith('png');
    });
  });

  describe('Metric Cards', () => {
    it('should display metric with trend indicator', () => {
      render(
        <MetricCard 
          title="Total Campaigns"
          value={24}
          trend={12.5}
          comparison="vs last month"
        />
      );
      
      expect(screen.getByText('Total Campaigns')).toBeInTheDocument();
      expect(screen.getByText('24')).toBeInTheDocument();
      expect(screen.getByText('+12.5%')).toBeInTheDocument();
      expect(screen.getByText('vs last month')).toBeInTheDocument();
    });

    it('should show positive and negative trends', () => {
      const { rerender } = render(
        <MetricCard 
          title="Active Users"
          value={1250}
          trend={-3.2}
          data-testid="negative-trend"
        />
      );
      
      expect(screen.getByTestId('negative-trend')).toHaveClass('trend-negative');
      expect(screen.getByText('-3.2%')).toBeInTheDocument();
      
      rerender(
        <MetricCard 
          title="Revenue"
          value={45600}
          trend={15.3}
          data-testid="positive-trend"
        />
      );
      
      expect(screen.getByTestId('positive-trend')).toHaveClass('trend-positive');
      expect(screen.getByText('+15.3%')).toBeInTheDocument();
    });

    it('should show loading state', () => {
      render(
        <MetricCard 
          title="Loading Metric"
          loading={true}
        />
      );
      
      expect(screen.getByTestId('metric-skeleton')).toBeInTheDocument();
      expect(screen.getByText('Loading Metric')).toBeInTheDocument();
    });

    it('should format large numbers', () => {
      render(
        <MetricCard 
          title="Page Views"
          value={1250000}
          formatNumber={true}
        />
      );
      
      expect(screen.getByText('1.25M')).toBeInTheDocument();
    });

    it('should support clickable metrics', async () => {
      const mockOnClick = jest.fn();
      
      render(
        <MetricCard 
          title="Clickable Metric"
          value={100}
          onClick={mockOnClick}
          clickable={true}
        />
      );
      
      await userEvent.click(screen.getByRole('button', { name: /clickable metric/i }));
      expect(mockOnClick).toHaveBeenCalled();
    });
  });

  describe('Time Range Picker', () => {
    const timePresets = [
      { label: 'Last 7 days', value: { start: '2024-10-24', end: '2024-10-31' } },
      { label: 'Last 30 days', value: { start: '2024-10-01', end: '2024-10-31' } },
      { label: 'Last 3 months', value: { start: '2024-08-01', end: '2024-10-31' } }
    ];

    it('should render time range options', () => {
      render(
        <TimeRangePicker 
          value={{ start: '2024-10-01', end: '2024-10-31' }}
          onChange={jest.fn()}
          presets={timePresets}
        />
      );
      
      timePresets.forEach(preset => {
        expect(screen.getByText(preset.label)).toBeInTheDocument();
      });
    });

    it('should handle preset selection', async () => {
      const mockOnChange = jest.fn();
      
      render(
        <TimeRangePicker 
          value={{ start: '2024-10-01', end: '2024-10-31' }}
          onChange={mockOnChange}
          presets={timePresets}
        />
      );
      
      await userEvent.click(screen.getByText('Last 7 days'));
      
      expect(mockOnChange).toHaveBeenCalledWith({
        start: '2024-10-24',
        end: '2024-10-31'
      });
    });

    it('should support custom date range', async () => {
      const mockOnChange = jest.fn();
      
      render(
        <TimeRangePicker 
          value={{ start: '2024-10-01', end: '2024-10-31' }}
          onChange={mockOnChange}
          customRange={true}
        />
      );
      
      const customButton = screen.getByText('Custom Range');
      await userEvent.click(customButton);
      
      const startDateInput = screen.getByLabelText(/start date/i);
      const endDateInput = screen.getByLabelText(/end date/i);
      
      await userEvent.clear(startDateInput);
      await userEvent.type(startDateInput, '2024-09-15');
      await userEvent.clear(endDateInput);
      await userEvent.type(endDateInput, '2024-10-15');
      
      const applyButton = screen.getByRole('button', { name: /apply/i });
      await userEvent.click(applyButton);
      
      expect(mockOnChange).toHaveBeenCalledWith({
        start: '2024-09-15',
        end: '2024-10-15'
      });
    });

    it('should validate date ranges', async () => {
      render(
        <TimeRangePicker 
          value={{ start: '2024-10-01', end: '2024-10-31' }}
          onChange={jest.fn()}
          customRange={true}
        />
      );
      
      const customButton = screen.getByText('Custom Range');
      await userEvent.click(customButton);
      
      const startDateInput = screen.getByLabelText(/start date/i);
      const endDateInput = screen.getByLabelText(/end date/i);
      
      // Set end date before start date
      await userEvent.clear(startDateInput);
      await userEvent.type(startDateInput, '2024-10-15');
      await userEvent.clear(endDateInput);
      await userEvent.type(endDateInput, '2024-10-01');
      
      expect(screen.getByText(/end date must be after start date/i))
        .toBeInTheDocument();
    });
  });

  describe('Data Table', () => {
    const columns = [
      { key: 'campaign', label: 'Campaign', sortable: true },
      { key: 'impressions', label: 'Impressions', sortable: true, type: 'number' },
      { key: 'clicks', label: 'Clicks', sortable: true, type: 'number' },
      { key: 'ctr', label: 'CTR', sortable: true, type: 'percentage' },
      { key: 'conversions', label: 'Conversions', sortable: true, type: 'number' },
      { key: 'cpa', label: 'CPA', sortable: false, type: 'currency' }
    ];

    it('should render data table with columns', () => {
      render(
        <DataTable 
          data={mockAnalyticsData.tableData}
          columns={columns}
        />
      );
      
      columns.forEach(column => {
        expect(screen.getByText(column.label)).toBeInTheDocument();
      });
      
      mockAnalyticsData.tableData.forEach(row => {
        expect(screen.getByText(row.campaign)).toBeInTheDocument();
      });
    });

    it('should support column sorting', async () => {
      const mockOnSort = jest.fn();
      
      render(
        <DataTable 
          data={mockAnalyticsData.tableData}
          columns={columns}
          onSort={mockOnSort}
        />
      );
      
      const impressionsHeader = screen.getByText('Impressions');
      await userEvent.click(impressionsHeader);
      
      expect(mockOnSort).toHaveBeenCalledWith('impressions', 'asc');
    });

    it('should support filtering', async () => {
      render(
        <DataTable 
          data={mockAnalyticsData.tableData}
          columns={columns}
          filterable={true}
        />
      );
      
      const filterInput = screen.getByPlaceholderText(/search/i);
      await userEvent.type(filterInput, 'Holiday');
      
      expect(screen.getByText('Holiday Campaign')).toBeInTheDocument();
      expect(screen.queryByText('Q4 Product Launch')).not.toBeInTheDocument();
    });

    it('should export table data', async () => {
      const mockOnExport = jest.fn();
      
      render(
        <DataTable 
          data={mockAnalyticsData.tableData}
          columns={columns}
          exportable={true}
          onExport={mockOnExport}
        />
      );
      
      const exportButton = screen.getByRole('button', { name: /export/i });
      await userEvent.click(exportButton);
      
      await userEvent.click(screen.getByText('CSV'));
      expect(mockOnExport).toHaveBeenCalledWith('csv', mockAnalyticsData.tableData);
    });

    it('should handle pagination', () => {
      const largeDataset = Array.from({ length: 50 }, (_, i) => ({
        campaign: `Campaign ${i + 1}`,
        impressions: Math.floor(Math.random() * 50000),
        clicks: Math.floor(Math.random() * 1000),
        ctr: parseFloat((Math.random() * 5).toFixed(2)),
        conversions: Math.floor(Math.random() * 100),
        cpa: `$${(Math.random() * 100).toFixed(2)}`
      }));
      
      render(
        <DataTable 
          data={largeDataset}
          columns={columns}
          pagination={{ pageSize: 10 }}
        />
      );
      
      expect(screen.getAllByRole('row')).toHaveLength(11); // 10 data + header
      expect(screen.getByText('1 of 5')).toBeInTheDocument();
    });
  });

  describe('Real-time Updates', () => {
    it('should show real-time indicator', () => {
      render(
        <RealtimeIndicator 
          active={true}
          lastUpdate={new Date('2024-10-31T10:30:00Z')}
        />
      );
      
      expect(screen.getByTestId('realtime-indicator')).toHaveClass('realtime-active');
      expect(screen.getByText(/last updated.*10:30/i)).toBeInTheDocument();
    });

    it('should handle WebSocket connections', () => {
      const mockWebSocket = {
        addEventListener: jest.fn(),
        removeEventListener: jest.fn(),
        send: jest.fn(),
        close: jest.fn(),
        readyState: WebSocket.OPEN
      };
      
      global.WebSocket = jest.fn(() => mockWebSocket);
      
      render(
        <AnalyticsDashboard 
          data={mockAnalyticsData}
          timeRange={{ start: '2024-10-01', end: '2024-10-31' }}
          realTime={true}
          websocketUrl="ws://localhost:3000/analytics"
        />
      );
      
      expect(global.WebSocket).toHaveBeenCalledWith('ws://localhost:3000/analytics');
      expect(mockWebSocket.addEventListener).toHaveBeenCalledWith('message', expect.any(Function));
    });

    it('should update data on WebSocket messages', async () => {
      const mockWebSocket = {
        addEventListener: jest.fn(),
        removeEventListener: jest.fn(),
        send: jest.fn(),
        close: jest.fn(),
        readyState: WebSocket.OPEN
      };
      
      global.WebSocket = jest.fn(() => mockWebSocket);
      
      render(
        <AnalyticsDashboard 
          data={mockAnalyticsData}
          timeRange={{ start: '2024-10-01', end: '2024-10-31' }}
          realTime={true}
          websocketUrl="ws://localhost:3000/analytics"
        />
      );
      
      // Simulate WebSocket message
      const messageHandler = mockWebSocket.addEventListener.mock.calls
        .find(call => call[0] === 'message')[1];
      
      const mockUpdate = {
        type: 'metrics_update',
        data: {
          totalCampaigns: { value: 25, trend: 13.2 }
        }
      };
      
      messageHandler({ data: JSON.stringify(mockUpdate) });
      
      await waitFor(() => {
        expect(screen.getByText('25')).toBeInTheDocument();
        expect(screen.getByText('+13.2%')).toBeInTheDocument();
      });
    });

    it('should handle connection failures gracefully', () => {
      const mockWebSocket = {
        addEventListener: jest.fn(),
        removeEventListener: jest.fn(),
        send: jest.fn(),
        close: jest.fn(),
        readyState: WebSocket.CLOSED
      };
      
      global.WebSocket = jest.fn(() => mockWebSocket);
      
      render(
        <AnalyticsDashboard 
          data={mockAnalyticsData}
          timeRange={{ start: '2024-10-01', end: '2024-10-31' }}
          realTime={true}
          websocketUrl="ws://localhost:3000/analytics"
        />
      );
      
      expect(screen.getByText(/connection lost/i)).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /reconnect/i })).toBeInTheDocument();
    });
  });

  describe('Performance Tests', () => {
    it('should render dashboard within 100ms', async () => {
      const renderTime = await global.testUtils.measureRenderTime(() => {
        render(
          <AnalyticsDashboard 
            data={mockAnalyticsData}
            timeRange={{ start: '2024-10-01', end: '2024-10-31' }}
          />
        );
      });
      
      expect(renderTime).toBeLessThan(100);
    });

    it('should handle large datasets efficiently', async () => {
      const largeDataset = {
        ...mockAnalyticsData,
        charts: {
          ...mockAnalyticsData.charts,
          campaignPerformance: {
            type: 'line',
            data: Array.from({ length: 1000 }, (_, i) => ({
              date: `2024-10-${String(i % 31 + 1).padStart(2, '0')}`,
              impressions: Math.floor(Math.random() * 50000),
              clicks: Math.floor(Math.random() * 1000),
              conversions: Math.floor(Math.random() * 100)
            }))
          }
        }
      };
      
      const renderTime = await global.testUtils.measureRenderTime(() => {
        render(
          <AnalyticsDashboard 
            data={largeDataset}
            timeRange={{ start: '2024-10-01', end: '2024-10-31' }}
          />
        );
      });
      
      expect(renderTime).toBeLessThan(100);
    });

    it('should optimize chart rendering', async () => {
      const renderTime = await global.testUtils.measureRenderTime(() => {
        render(
          <InteractiveChart 
            type="line"
            data={mockAnalyticsData.charts.campaignPerformance.data}
            optimized={true}
          />
        );
      });
      
      expect(renderTime).toBeLessThan(50); // Charts should be even faster
    });
  });

  describe('Accessibility', () => {
    it('should have no accessibility violations', async () => {
      const { container } = render(
        <AnalyticsDashboard 
          data={mockAnalyticsData}
          timeRange={{ start: '2024-10-01', end: '2024-10-31' }}
        />
      );
      
      const results = await axe(container, global.axeConfig);
      expect(results).toHaveNoViolations();
    });

    it('should provide chart data in accessible format', () => {
      render(
        <InteractiveChart 
          type="line"
          data={mockAnalyticsData.charts.campaignPerformance.data}
          accessibleData={true}
        />
      );
      
      // Should have accessible data table
      expect(screen.getByRole('table', { name: /chart data/i })).toBeInTheDocument();
      expect(screen.getByText('12,500')).toBeInTheDocument(); // First data point
    });

    it('should support keyboard navigation for charts', async () => {
      render(
        <InteractiveChart 
          type="line"
          data={mockAnalyticsData.charts.campaignPerformance.data}
          keyboardNavigable={true}
        />
      );
      
      const chart = screen.getByRole('application', { name: /chart/i });
      chart.focus();
      
      await userEvent.keyboard('{ArrowRight}');
      expect(screen.getByText(/data point 2/i)).toHaveAttribute('aria-current', 'true');
    });

    it('should announce data updates to screen readers', async () => {
      render(
        <AnalyticsDashboard 
          data={mockAnalyticsData}
          timeRange={{ start: '2024-10-01', end: '2024-10-31' }}
          announceUpdates={true}
        />
      );
      
      // Simulate data update
      const updatedData = {
        ...mockAnalyticsData,
        metrics: {
          ...mockAnalyticsData.metrics,
          totalCampaigns: { value: 25, trend: 13.2 }
        }
      };
      
      // This would typically be triggered by a prop change
      expect(screen.getByText('Dashboard updated with new data'))
        .toHaveAttribute('aria-live', 'polite');
    });
  });

  describe('Responsive Design', () => {
    const breakpoints = [320, 768, 1024, 1440, 2560];

    breakpoints.forEach(width => {
      it(`should adapt layout at ${width}px`, () => {
        global.testUtils.mockViewport(width, 800);
        
        render(
          <AnalyticsDashboard 
            data={mockAnalyticsData}
            timeRange={{ start: '2024-10-01', end: '2024-10-31' }}
            responsive={true}
            data-testid={`dashboard-${width}`}
          />
        );
        
        const dashboard = screen.getByTestId(`dashboard-${width}`);
        
        if (width < 768) {
          expect(dashboard).toHaveClass('dashboard-mobile');
        } else if (width < 1024) {
          expect(dashboard).toHaveClass('dashboard-tablet');
        } else {
          expect(dashboard).toHaveClass('dashboard-desktop');
        }
      });
    });

    it('should stack metric cards on mobile', () => {
      global.testUtils.mockViewport(320, 568);
      
      render(
        <AnalyticsDashboard 
          data={mockAnalyticsData}
          timeRange={{ start: '2024-10-01', end: '2024-10-31' }}
          responsive={true}
        />
      );
      
      const metricsContainer = screen.getByTestId('metrics-section');
      expect(metricsContainer).toHaveClass('metrics-stacked');
    });

    it('should adapt chart sizes for different screens', () => {
      const sizes = [
        { width: 320, expectedClass: 'chart-small' },
        { width: 768, expectedClass: 'chart-medium' },
        { width: 1440, expectedClass: 'chart-large' }
      ];
      
      sizes.forEach(({ width, expectedClass }) => {
        global.testUtils.mockViewport(width, 800);
        
        render(
          <InteractiveChart 
            type="line"
            data={mockAnalyticsData.charts.campaignPerformance.data}
            responsive={true}
            data-testid={`chart-${width}`}
          />
        );
        
        expect(screen.getByTestId(`chart-${width}`)).toHaveClass(expectedClass);
      });
    });
  });

  describe('Error Handling', () => {
    it('should handle data loading errors', () => {
      render(
        <AnalyticsDashboard 
          data={null}
          error="Failed to load analytics data"
          timeRange={{ start: '2024-10-01', end: '2024-10-31' }}
        />
      );
      
      expect(screen.getByText(/failed to load analytics data/i)).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /retry/i })).toBeInTheDocument();
    });

    it('should show fallback for missing chart data', () => {
      const incompleteData = {
        ...mockAnalyticsData,
        charts: {}
      };
      
      render(
        <AnalyticsDashboard 
          data={incompleteData}
          timeRange={{ start: '2024-10-01', end: '2024-10-31' }}
        />
      );
      
      expect(screen.getByText(/no chart data available/i)).toBeInTheDocument();
    });

    it('should handle chart rendering errors', () => {
      const consoleSpy = jest.spyOn(console, 'error').mockImplementation();
      
      render(
        <InteractiveChart 
          type="invalid-type"
          data={mockAnalyticsData.charts.campaignPerformance.data}
        />
      );
      
      expect(screen.getByText(/chart failed to render/i)).toBeInTheDocument();
      
      consoleSpy.mockRestore();
    });
  });
});

// Export components for integration tests
export { 
  AnalyticsDashboard, 
  InteractiveChart, 
  MetricCard, 
  TimeRangePicker, 
  DataTable,
  RealtimeIndicator 
};