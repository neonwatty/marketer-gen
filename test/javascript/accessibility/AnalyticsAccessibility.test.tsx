import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { axe, toHaveNoViolations } from 'jest-axe';

expect.extend(toHaveNoViolations);

// Analytics dashboard interactive charts accessibility testing
describe('Analytics Dashboard Accessibility', () => {
  const wcagConfig = {
    rules: {
      'color-contrast': { enabled: true },
      'aria-allowed-attr': { enabled: true },
      'aria-required-attr': { enabled: true },
      'aria-roles': { enabled: true },
      'aria-valid-attr': { enabled: true },
      'aria-valid-attr-value': { enabled: true },
      'button-name': { enabled: true },
      'image-alt': { enabled: true },
      'label': { enabled: true },
      'region': { enabled: true },
      'tabindex': { enabled: true }
    },
    tags: ['wcag2a', 'wcag2aa', 'wcag21aa']
  };

  it('should provide accessible interactive charts with keyboard navigation', async () => {
    const InteractiveChart = () => {
      const [chartType, setChartType] = React.useState('line');
      const [selectedDataPoint, setSelectedDataPoint] = React.useState(0);
      const [showDataTable, setShowDataTable] = React.useState(false);

      const data = [
        { month: 'Jan', value: 4000, label: 'January: $4,000' },
        { month: 'Feb', value: 3000, label: 'February: $3,000' },
        { month: 'Mar', value: 5000, label: 'March: $5,000' },
        { month: 'Apr', value: 4500, label: 'April: $4,500' },
        { month: 'May', value: 6000, label: 'May: $6,000' },
        { month: 'Jun', value: 5500, label: 'June: $5,500' }
      ];

      const handleKeyDown = (e: React.KeyboardEvent) => {
        switch (e.key) {
          case 'ArrowLeft':
            e.preventDefault();
            setSelectedDataPoint(Math.max(0, selectedDataPoint - 1));
            break;
          case 'ArrowRight':
            e.preventDefault();
            setSelectedDataPoint(Math.min(data.length - 1, selectedDataPoint + 1));
            break;
          case 'Home':
            e.preventDefault();
            setSelectedDataPoint(0);
            break;
          case 'End':
            e.preventDefault();
            setSelectedDataPoint(data.length - 1);
            break;
          case 'Enter':
          case ' ':
            e.preventDefault();
            setShowDataTable(!showDataTable);
            break;
        }
      };

      return (
        <div role="region" aria-labelledby="chart-title">
          <h2 id="chart-title">Revenue Analytics</h2>
          
          {/* Chart type selector */}
          <div role="group" aria-label="Chart type selection">
            <label htmlFor="chart-type">Chart Type:</label>
            <select
              id="chart-type"
              value={chartType}
              onChange={(e) => setChartType(e.target.value)}
            >
              <option value="line">Line Chart</option>
              <option value="bar">Bar Chart</option>
              <option value="area">Area Chart</option>
            </select>
          </div>

          {/* Interactive chart */}
          <div 
            role="img"
            aria-labelledby="chart-title"
            aria-describedby="chart-desc chart-instructions"
            tabIndex={0}
            onKeyDown={handleKeyDown}
            style={{ 
              border: '2px solid #007bff',
              padding: '20px',
              backgroundColor: '#f8f9fa'
            }}
          >
            <div id="chart-desc">
              {chartType.charAt(0).toUpperCase() + chartType.slice(1)} chart showing monthly revenue data
            </div>
            
            <div id="chart-instructions" className="sr-only">
              Use arrow keys to navigate between data points, Home/End to go to first/last point, 
              Enter or Space to toggle data table view.
            </div>

            {/* Visual chart representation */}
            <svg width="500" height="300" aria-hidden="true">
              {data.map((point, index) => (
                <g key={point.month}>
                  {chartType === 'line' && index > 0 && (
                    <line
                      x1={50 + (index - 1) * 75}
                      y1={250 - (data[index - 1].value / 100)}
                      x2={50 + index * 75}
                      y2={250 - (point.value / 100)}
                      stroke="#007bff"
                      strokeWidth={selectedDataPoint === index ? "3" : "2"}
                    />
                  )}
                  
                  <circle
                    cx={50 + index * 75}
                    cy={250 - (point.value / 100)}
                    r={selectedDataPoint === index ? "8" : "5"}
                    fill={selectedDataPoint === index ? "#0056b3" : "#007bff"}
                  />
                  
                  <text
                    x={50 + index * 75}
                    y={280}
                    textAnchor="middle"
                    fontSize="12"
                  >
                    {point.month}
                  </text>
                </g>
              ))}
            </svg>

            {/* Live region for screen reader announcements */}
            <div role="status" aria-live="polite" aria-atomic="true" className="sr-only">
              {selectedDataPoint !== null && 
                `Selected: ${data[selectedDataPoint]?.label}`
              }
            </div>
          </div>

          {/* Chart legend */}
          <div role="group" aria-label="Chart legend">
            <h3>Legend</h3>
            <ul role="list">
              <li>
                <span 
                  style={{ 
                    display: 'inline-block', 
                    width: '20px', 
                    height: '3px', 
                    backgroundColor: '#007bff',
                    marginRight: '8px'
                  }}
                  aria-hidden="true"
                />
                Monthly Revenue
              </li>
            </ul>
          </div>

          {/* Data table toggle */}
          <button
            type="button"
            aria-expanded={showDataTable}
            aria-controls="data-table"
            onClick={() => setShowDataTable(!showDataTable)}
          >
            {showDataTable ? 'Hide' : 'Show'} Data Table
          </button>

          {/* Accessible data table */}
          {showDataTable && (
            <table id="data-table" role="table" aria-labelledby="table-title">
              <caption id="table-title">Monthly revenue data in tabular format</caption>
              <thead>
                <tr>
                  <th scope="col">Month</th>
                  <th scope="col">Revenue (USD)</th>
                  <th scope="col">Change from Previous</th>
                </tr>
              </thead>
              <tbody>
                {data.map((point, index) => {
                  const prevValue = index > 0 ? data[index - 1].value : point.value;
                  const change = index > 0 ? ((point.value - prevValue) / prevValue) * 100 : 0;
                  
                  return (
                    <tr key={point.month}>
                      <th scope="row">{point.month}</th>
                      <td>${point.value.toLocaleString()}</td>
                      <td aria-label={`${change >= 0 ? 'Increase' : 'Decrease'} of ${Math.abs(change).toFixed(1)} percent`}>
                        {index > 0 ? `${change >= 0 ? '+' : ''}${change.toFixed(1)}%` : 'N/A'}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>
      );
    };

    const { container } = render(<InteractiveChart />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Test keyboard navigation
    const chart = screen.getByRole('img', { name: /line chart showing monthly revenue/i });
    chart.focus();
    expect(chart).toHaveFocus();

    // Test arrow key navigation
    await userEvent.keyboard('{ArrowRight}');
    
    // Should announce the new data point
    await waitFor(() => {
      expect(screen.getByRole('status')).toHaveTextContent('February: $3,000');
    });

    // Test data table toggle
    const tableToggle = screen.getByRole('button', { name: /show data table/i });
    await userEvent.click(tableToggle);
    
    expect(tableToggle).toHaveAttribute('aria-expanded', 'true');
    expect(screen.getByRole('table')).toBeInTheDocument();
  });

  it('should provide accessible dashboard with multiple chart types', async () => {
    const AnalyticsDashboard = () => {
      const [selectedMetric, setSelectedMetric] = React.useState('revenue');
      const [timeframe, setTimeframe] = React.useState('monthly');
      const [loading, setLoading] = React.useState(false);

      const metrics = {
        revenue: { label: 'Revenue', value: '$125,000', change: '+12.5%', color: '#28a745' },
        users: { label: 'Active Users', value: '8,547', change: '+8.3%', color: '#007bff' },
        conversions: { label: 'Conversions', value: '1,234', change: '-3.2%', color: '#dc3545' },
        retention: { label: 'Retention Rate', value: '87.5%', change: '+2.1%', color: '#ffc107' }
      };

      const updateDashboard = async (metric: string, timeframe: string) => {
        setLoading(true);
        // Simulate API call
        setTimeout(() => {
          setLoading(false);
        }, 1000);
      };

      React.useEffect(() => {
        updateDashboard(selectedMetric, timeframe);
      }, [selectedMetric, timeframe]);

      return (
        <div role="region" aria-labelledby="dashboard-title">
          <h1 id="dashboard-title">Analytics Dashboard</h1>
          
          {/* Dashboard controls */}
          <div role="group" aria-label="Dashboard filters">
            <div>
              <label htmlFor="metric-select">Select Metric:</label>
              <select
                id="metric-select"
                value={selectedMetric}
                onChange={(e) => setSelectedMetric(e.target.value)}
                aria-describedby="metric-help"
              >
                {Object.entries(metrics).map(([key, metric]) => (
                  <option key={key} value={key}>{metric.label}</option>
                ))}
              </select>
              <div id="metric-help" className="sr-only">
                Choose which metric to display in the main chart
              </div>
            </div>

            <fieldset>
              <legend>Time Frame</legend>
              <div role="radiogroup">
                {[
                  { value: 'daily', label: 'Daily' },
                  { value: 'weekly', label: 'Weekly' },
                  { value: 'monthly', label: 'Monthly' },
                  { value: 'yearly', label: 'Yearly' }
                ].map((option) => (
                  <label key={option.value}>
                    <input
                      type="radio"
                      name="timeframe"
                      value={option.value}
                      checked={timeframe === option.value}
                      onChange={(e) => setTimeframe(e.target.value)}
                    />
                    {option.label}
                  </label>
                ))}
              </div>
            </fieldset>
          </div>

          {/* Loading state */}
          {loading && (
            <div role="status" aria-live="polite">
              <span className="sr-only">Loading dashboard data...</span>
              <div aria-hidden="true">Loading...</div>
            </div>
          )}

          {/* Key metrics overview */}
          <div role="group" aria-label="Key metrics overview" aria-live="polite">
            <h2>Key Metrics</h2>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '20px' }}>
              {Object.entries(metrics).map(([key, metric]) => (
                <div 
                  key={key}
                  role="img"
                  aria-labelledby={`${key}-label`}
                  aria-describedby={`${key}-change`}
                  style={{
                    padding: '20px',
                    border: selectedMetric === key ? '3px solid #007bff' : '1px solid #ddd',
                    borderRadius: '8px',
                    backgroundColor: selectedMetric === key ? '#f8f9fa' : '#fff'
                  }}
                >
                  <h3 id={`${key}-label`}>{metric.label}</h3>
                  <div style={{ fontSize: '2rem', color: metric.color, fontWeight: 'bold' }}>
                    {metric.value}
                  </div>
                  <div id={`${key}-change`} style={{ color: metric.change.startsWith('+') ? '#28a745' : '#dc3545' }}>
                    {metric.change} from last period
                  </div>
                  
                  {selectedMetric === key && (
                    <div className="sr-only">Currently selected metric</div>
                  )}
                </div>
              ))}
            </div>
          </div>

          {/* Main chart area */}
          <div role="region" aria-labelledby="main-chart-title">
            <h2 id="main-chart-title">
              {metrics[selectedMetric as keyof typeof metrics].label} Trend ({timeframe})
            </h2>
            
            {!loading && (
              <div 
                role="img"
                aria-labelledby="main-chart-title"
                aria-describedby="main-chart-desc"
                tabIndex={0}
                style={{
                  height: '400px',
                  border: '1px solid #ddd',
                  borderRadius: '8px',
                  padding: '20px',
                  backgroundColor: '#fff'
                }}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    // Toggle detailed view or data table
                  }
                }}
              >
                <div id="main-chart-desc">
                  Interactive chart showing {metrics[selectedMetric as keyof typeof metrics].label.toLowerCase()} 
                  data over time with {timeframe} intervals
                </div>
                
                {/* Placeholder chart visualization */}
                <svg width="100%" height="300" aria-hidden="true">
                  <line x1="0" y1="250" x2="100%" y2="100" stroke={metrics[selectedMetric as keyof typeof metrics].color} strokeWidth="3"/>
                  <circle cx="20%" cy="200" r="5" fill={metrics[selectedMetric as keyof typeof metrics].color}/>
                  <circle cx="40%" cy="180" r="5" fill={metrics[selectedMetric as keyof typeof metrics].color}/>
                  <circle cx="60%" cy="150" r="5" fill={metrics[selectedMetric as keyof typeof metrics].color}/>
                  <circle cx="80%" cy="120" r="5" fill={metrics[selectedMetric as keyof typeof metrics].color}/>
                </svg>

                {/* Screen reader summary */}
                <div className="sr-only">
                  Chart shows {metrics[selectedMetric as keyof typeof metrics].label} trending 
                  {metrics[selectedMetric as keyof typeof metrics].change.startsWith('+') ? 'upward' : 'downward'} 
                  with current value of {metrics[selectedMetric as keyof typeof metrics].value}
                </div>
              </div>
            )}
          </div>

          {/* Comparison charts */}
          <div role="region" aria-labelledby="comparison-title">
            <h2 id="comparison-title">Metric Comparison</h2>
            
            <div role="group" aria-label="Comparison charts">
              {/* Mini charts for other metrics */}
              {Object.entries(metrics)
                .filter(([key]) => key !== selectedMetric)
                .map(([key, metric]) => (
                  <div 
                    key={key}
                    role="img"
                    aria-labelledby={`mini-${key}-title`}
                    aria-describedby={`mini-${key}-desc`}
                    style={{
                      display: 'inline-block',
                      width: '200px',
                      height: '100px',
                      margin: '10px',
                      padding: '10px',
                      border: '1px solid #ddd',
                      borderRadius: '4px'
                    }}
                  >
                    <h3 id={`mini-${key}-title`} style={{ fontSize: '14px', margin: '0 0 5px 0' }}>
                      {metric.label}
                    </h3>
                    
                    <div style={{ fontSize: '18px', fontWeight: 'bold', color: metric.color }}>
                      {metric.value}
                    </div>
                    
                    <div id={`mini-${key}-desc`} style={{ fontSize: '12px', color: '#666' }}>
                      {metric.change} change
                    </div>

                    {/* Mini chart */}
                    <svg width="100%" height="30" aria-hidden="true">
                      <polyline
                        points="0,25 40,20 80,15 120,10 160,12 180,8"
                        fill="none"
                        stroke={metric.color}
                        strokeWidth="2"
                      />
                    </svg>
                  </div>
                ))}
            </div>
          </div>

          {/* Data export options */}
          <div role="group" aria-label="Export options">
            <h2>Export Data</h2>
            <button 
              type="button"
              aria-describedby="csv-export-desc"
            >
              Export as CSV
            </button>
            <div id="csv-export-desc" className="sr-only">
              Download current dashboard data as CSV file
            </div>
            
            <button 
              type="button"
              aria-describedby="pdf-export-desc"
            >
              Export as PDF Report
            </button>
            <div id="pdf-export-desc" className="sr-only">
              Generate and download PDF report with charts and data
            </div>
          </div>
        </div>
      );
    };

    const { container } = render(<AnalyticsDashboard />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Wait for initial loading to complete
    await waitFor(() => {
      expect(screen.queryByText('Loading...')).not.toBeInTheDocument();
    });

    // Test metric selection
    const metricSelect = screen.getByLabelText('Select Metric:');
    await userEvent.selectOptions(metricSelect, 'users');
    
    expect(screen.getByText('Active Users Trend (monthly)')).toBeInTheDocument();

    // Test timeframe selection
    const weeklyRadio = screen.getByRole('radio', { name: 'Weekly' });
    await userEvent.click(weeklyRadio);
    
    expect(weeklyRadio).toBeChecked();

    // Test chart focus
    const mainChart = screen.getByRole('img', { name: /interactive chart showing active users/i });
    mainChart.focus();
    expect(mainChart).toHaveFocus();
  });

  it('should provide accessible chart customization and drill-down', async () => {
    const CustomizableChart = () => {
      const [filters, setFilters] = React.useState({
        dateRange: '30d',
        segments: [] as string[],
        breakdown: 'daily'
      });
      const [drilldownLevel, setDrilldownLevel] = React.useState(0);
      const [customizationOpen, setCustomizationOpen] = React.useState(false);

      const drilldownData = [
        { level: 0, title: 'Overall Performance', data: 'High-level metrics' },
        { level: 1, title: 'Channel Breakdown', data: 'Performance by channel' },
        { level: 2, title: 'Campaign Details', data: 'Individual campaign performance' }
      ];

      const handleSegmentChange = (segment: string, checked: boolean) => {
        setFilters(prev => ({
          ...prev,
          segments: checked 
            ? [...prev.segments, segment]
            : prev.segments.filter(s => s !== segment)
        }));
      };

      return (
        <div role="region" aria-labelledby="customizable-chart-title">
          <h2 id="customizable-chart-title">Customizable Analytics Chart</h2>
          
          {/* Chart customization panel */}
          <div>
            <button
              type="button"
              aria-expanded={customizationOpen}
              aria-controls="customization-panel"
              onClick={() => setCustomizationOpen(!customizationOpen)}
            >
              Chart Settings
            </button>
            
            <div id="customization-panel" hidden={!customizationOpen}>
              <h3>Customize Chart</h3>
              
              {/* Date range selector */}
              <div>
                <label htmlFor="date-range">Date Range:</label>
                <select
                  id="date-range"
                  value={filters.dateRange}
                  onChange={(e) => setFilters(prev => ({ ...prev, dateRange: e.target.value }))}
                >
                  <option value="7d">Last 7 days</option>
                  <option value="30d">Last 30 days</option>
                  <option value="90d">Last 90 days</option>
                  <option value="1y">Last year</option>
                </select>
              </div>

              {/* Segment filters */}
              <fieldset>
                <legend>Segments to Include</legend>
                <div role="group">
                  {[
                    { value: 'desktop', label: 'Desktop Users' },
                    { value: 'mobile', label: 'Mobile Users' },
                    { value: 'tablet', label: 'Tablet Users' },
                    { value: 'new', label: 'New Visitors' },
                    { value: 'returning', label: 'Returning Visitors' }
                  ].map((segment) => (
                    <label key={segment.value}>
                      <input
                        type="checkbox"
                        value={segment.value}
                        checked={filters.segments.includes(segment.value)}
                        onChange={(e) => handleSegmentChange(segment.value, e.target.checked)}
                      />
                      {segment.label}
                    </label>
                  ))}
                </div>
              </fieldset>

              {/* Data breakdown */}
              <fieldset>
                <legend>Data Breakdown</legend>
                <div role="radiogroup">
                  {[
                    { value: 'hourly', label: 'Hourly' },
                    { value: 'daily', label: 'Daily' },
                    { value: 'weekly', label: 'Weekly' },
                    { value: 'monthly', label: 'Monthly' }
                  ].map((option) => (
                    <label key={option.value}>
                      <input
                        type="radio"
                        name="breakdown"
                        value={option.value}
                        checked={filters.breakdown === option.value}
                        onChange={(e) => setFilters(prev => ({ ...prev, breakdown: e.target.value }))}
                      />
                      {option.label}
                    </label>
                  ))}
                </div>
              </fieldset>
            </div>
          </div>

          {/* Breadcrumb navigation for drill-down */}
          <nav aria-label="Chart drill-down navigation">
            <ol role="list">
              {drilldownData.slice(0, drilldownLevel + 1).map((level, index) => (
                <li key={level.level}>
                  {index < drilldownLevel ? (
                    <button
                      type="button"
                      onClick={() => setDrilldownLevel(index)}
                    >
                      {level.title}
                    </button>
                  ) : (
                    <span aria-current="page">{level.title}</span>
                  )}
                  {index < drilldownLevel && <span aria-hidden="true"> / </span>}
                </li>
              ))}
            </ol>
          </nav>

          {/* Main chart with drill-down capability */}
          <div 
            role="img"
            aria-labelledby="main-chart-title"
            aria-describedby="main-chart-desc drill-down-instructions"
            tabIndex={0}
            style={{
              height: '400px',
              border: '2px solid #007bff',
              borderRadius: '8px',
              padding: '20px',
              backgroundColor: '#f8f9fa'
            }}
            onKeyDown={(e) => {
              if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                if (drilldownLevel < drilldownData.length - 1) {
                  setDrilldownLevel(drilldownLevel + 1);
                }
              } else if (e.key === 'Escape') {
                if (drilldownLevel > 0) {
                  setDrilldownLevel(drilldownLevel - 1);
                }
              }
            }}
            onClick={() => {
              if (drilldownLevel < drilldownData.length - 1) {
                setDrilldownLevel(drilldownLevel + 1);
              }
            }}
          >
            <div id="main-chart-desc">
              {drilldownData[drilldownLevel].title} - {drilldownData[drilldownLevel].data}
            </div>
            
            <div id="drill-down-instructions" className="sr-only">
              Press Enter or Space to drill down into more detailed data. 
              Press Escape to go back to previous level.
            </div>

            {/* Chart visualization */}
            <svg width="100%" height="300" aria-hidden="true">
              <rect 
                width="80%" 
                height="200" 
                x="10%" 
                y="50" 
                fill="rgba(0, 123, 255, 0.3)" 
                stroke="#007bff" 
                strokeWidth="2"
              />
              <text x="50%" y="160" textAnchor="middle" fontSize="16">
                {drilldownData[drilldownLevel].title}
              </text>
            </svg>
          </div>

          {/* Chart actions */}
          <div role="toolbar" aria-label="Chart actions">
            <button
              type="button"
              disabled={drilldownLevel >= drilldownData.length - 1}
              aria-describedby="drill-down-desc"
            >
              Drill Down
            </button>
            <div id="drill-down-desc" className="sr-only">
              View more detailed breakdown of the current data
            </div>
            
            <button
              type="button"
              disabled={drilldownLevel === 0}
              onClick={() => setDrilldownLevel(Math.max(0, drilldownLevel - 1))}
              aria-describedby="drill-up-desc"
            >
              Drill Up
            </button>
            <div id="drill-up-desc" className="sr-only">
              Return to higher level view
            </div>
            
            <button
              type="button"
              onClick={() => setDrilldownLevel(0)}
              aria-describedby="reset-desc"
            >
              Reset View
            </button>
            <div id="reset-desc" className="sr-only">
              Return to top-level overview
            </div>
          </div>

          {/* Current filter summary */}
          <div role="status" aria-live="polite" aria-label="Current filters">
            <h3>Applied Filters</h3>
            <ul>
              <li>Date Range: {filters.dateRange}</li>
              <li>Breakdown: {filters.breakdown}</li>
              <li>
                Segments: {filters.segments.length === 0 ? 'All' : filters.segments.join(', ')}
              </li>
              <li>Drill-down Level: {drilldownData[drilldownLevel].title}</li>
            </ul>
          </div>
        </div>
      );
    };

    const { container } = render(<CustomizableChart />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Test customization panel
    const settingsButton = screen.getByRole('button', { name: 'Chart Settings' });
    expect(settingsButton).toHaveAttribute('aria-expanded', 'false');
    
    await userEvent.click(settingsButton);
    expect(settingsButton).toHaveAttribute('aria-expanded', 'true');

    // Test filter changes
    const desktopCheckbox = screen.getByRole('checkbox', { name: 'Desktop Users' });
    await userEvent.click(desktopCheckbox);
    expect(desktopCheckbox).toBeChecked();

    // Test drill-down functionality
    const mainChart = screen.getByRole('img');
    mainChart.focus();
    expect(mainChart).toHaveFocus();

    await userEvent.keyboard('{Enter}');
    
    // Should drill down to next level
    expect(screen.getByText('Channel Breakdown')).toBeInTheDocument();

    // Test drill-up
    const drillUpButton = screen.getByRole('button', { name: 'Drill Up' });
    expect(drillUpButton).not.toBeDisabled();
    
    await userEvent.click(drillUpButton);
    expect(screen.getByText('Overall Performance')).toBeInTheDocument();
  });
});