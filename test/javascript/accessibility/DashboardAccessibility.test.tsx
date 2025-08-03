import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { axe, toHaveNoViolations } from 'jest-axe';

expect.extend(toHaveNoViolations);

// Dashboard widgets accessibility testing
describe('Dashboard Widgets Accessibility', () => {
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
      'link-name': { enabled: true },
      'list': { enabled: true },
      'listitem': { enabled: true },
      'region': { enabled: true },
      'heading-order': { enabled: true },
      'document-title': { enabled: true },
      'tabindex': { enabled: true }
    },
    tags: ['wcag2a', 'wcag2aa', 'wcag21aa']
  };

  it('should have accessible performance metrics widget', async () => {
    const PerformanceWidget = () => (
      <div role="region" aria-labelledby="perf-title">
        <h2 id="perf-title">Campaign Performance</h2>
        
        {/* Key metrics cards */}
        <div role="group" aria-label="Key performance indicators">
          <div role="img" aria-labelledby="impressions-label" aria-describedby="impressions-desc">
            <div id="impressions-label">Impressions</div>
            <div aria-hidden="true" style={{ fontSize: '2rem', color: '#007bff' }}>125K</div>
            <div id="impressions-desc">12.5% increase from last month</div>
          </div>
          
          <div role="img" aria-labelledby="clicks-label" aria-describedby="clicks-desc">
            <div id="clicks-label">Clicks</div>
            <div aria-hidden="true" style={{ fontSize: '2rem', color: '#28a745' }}>3.2K</div>
            <div id="clicks-desc">8.3% increase from last month</div>
          </div>
          
          <div role="img" aria-labelledby="ctr-label" aria-describedby="ctr-desc">
            <div id="ctr-label">Click-through Rate</div>
            <div aria-hidden="true" style={{ fontSize: '2rem', color: '#ffc107' }}>2.56%</div>
            <div id="ctr-desc">3.1% decrease from last month</div>
          </div>
        </div>

        {/* Interactive chart */}
        <div role="img" aria-labelledby="chart-title" aria-describedby="chart-desc">
          <h3 id="chart-title">Performance Trend</h3>
          <p id="chart-desc">Line chart showing campaign performance over the last 30 days</p>
          
          {/* Chart visualization */}
          <svg width="400" height="200" aria-hidden="true">
            <line x1="0" y1="100" x2="400" y2="50" stroke="#007bff" strokeWidth="2"/>
            <circle cx="100" cy="75" r="3" fill="#007bff"/>
            <circle cx="200" cy="60" r="3" fill="#007bff"/>
            <circle cx="300" cy="45" r="3" fill="#007bff"/>
            <circle cx="400" cy="50" r="3" fill="#007bff"/>
          </svg>
          
          {/* Accessible data table for screen readers */}
          <table className="sr-only">
            <caption>Performance data by week</caption>
            <thead>
              <tr>
                <th scope="col">Week</th>
                <th scope="col">Impressions</th>
                <th scope="col">Clicks</th>
                <th scope="col">CTR</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <th scope="row">Week 1</th>
                <td>30,000</td>
                <td>750</td>
                <td>2.50%</td>
              </tr>
              <tr>
                <th scope="row">Week 2</th>
                <td>32,000</td>
                <td>800</td>
                <td>2.50%</td>
              </tr>
              <tr>
                <th scope="row">Week 3</th>
                <td>31,000</td>
                <td>810</td>
                <td>2.61%</td>
              </tr>
              <tr>
                <th scope="row">Week 4</th>
                <td>32,000</td>
                <td>840</td>
                <td>2.63%</td>
              </tr>
            </tbody>
          </table>
        </div>

        {/* Action buttons */}
        <div role="group" aria-label="Widget actions">
          <button type="button" aria-describedby="refresh-desc">
            <span aria-hidden="true">🔄</span>
            Refresh Data
          </button>
          <div id="refresh-desc" className="sr-only">Refresh the performance metrics data</div>
          
          <button type="button" aria-describedby="export-desc">
            <span aria-hidden="true">📊</span>
            Export Report
          </button>
          <div id="export-desc" className="sr-only">Export performance data as CSV</div>
        </div>
      </div>
    );

    const { container } = render(<PerformanceWidget />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();
    
    // Test keyboard navigation
    const refreshButton = screen.getByRole('button', { name: /refresh data/i });
    const exportButton = screen.getByRole('button', { name: /export report/i });
    
    refreshButton.focus();
    expect(refreshButton).toHaveFocus();
    
    await userEvent.tab();
    expect(exportButton).toHaveFocus();
  });

  it('should have accessible analytics dashboard widget', async () => {
    const AnalyticsWidget = () => {
      const [timeRange, setTimeRange] = React.useState('7d');
      const [loading, setLoading] = React.useState(false);
      
      return (
        <div role="region" aria-labelledby="analytics-title">
          <h2 id="analytics-title">Analytics Dashboard</h2>
          
          {/* Time range selector */}
          <fieldset>
            <legend>Select time range</legend>
            <div role="radiogroup" aria-label="Time range options">
              <label>
                <input 
                  type="radio" 
                  name="timeRange" 
                  value="1d"
                  checked={timeRange === '1d'}
                  onChange={(e) => setTimeRange(e.target.value)}
                />
                Last 24 hours
              </label>
              <label>
                <input 
                  type="radio" 
                  name="timeRange" 
                  value="7d"
                  checked={timeRange === '7d'}
                  onChange={(e) => setTimeRange(e.target.value)}
                />
                Last 7 days
              </label>
              <label>
                <input 
                  type="radio" 
                  name="timeRange" 
                  value="30d"
                  checked={timeRange === '30d'}
                  onChange={(e) => setTimeRange(e.target.value)}
                />
                Last 30 days
              </label>
            </div>
          </fieldset>

          {/* Real-time metrics */}
          <div role="group" aria-label="Real-time metrics" aria-live="polite">
            <div>
              <h3>Active Users</h3>
              <div aria-label="1,234 active users">1,234</div>
            </div>
            <div>
              <h3>Page Views</h3>
              <div aria-label="5,678 page views">5,678</div>
            </div>
            <div>
              <h3>Conversion Rate</h3>
              <div aria-label="3.45 percent conversion rate">3.45%</div>
            </div>
          </div>

          {/* Interactive chart with keyboard support */}
          <div 
            role="application" 
            aria-label="Interactive analytics chart"
            tabIndex={0}
            onKeyDown={(e) => {
              if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') {
                // Handle chart navigation
                e.preventDefault();
              }
            }}
          >
            <h3>Traffic Sources</h3>
            <div role="img" aria-describedby="traffic-desc">
              <p id="traffic-desc">
                Pie chart showing traffic sources: Direct 45%, Social Media 30%, Search 25%
              </p>
              
              {/* Visual chart */}
              <svg width="300" height="300" aria-hidden="true">
                <circle cx="150" cy="150" r="100" fill="#007bff" opacity="0.8"/>
                <circle cx="150" cy="150" r="100" fill="#28a745" opacity="0.8" 
                        transform="rotate(162 150 150)"/>
                <circle cx="150" cy="150" r="100" fill="#ffc107" opacity="0.8"
                        transform="rotate(270 150 150)"/>
              </svg>
            </div>
            
            {/* Accessible data for screen readers */}
            <table className="sr-only">
              <caption>Traffic sources breakdown</caption>
              <thead>
                <tr>
                  <th scope="col">Source</th>
                  <th scope="col">Percentage</th>
                  <th scope="col">Sessions</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <th scope="row">Direct</th>
                  <td>45%</td>
                  <td>2,250</td>
                </tr>
                <tr>
                  <th scope="row">Social Media</th>
                  <td>30%</td>
                  <td>1,500</td>
                </tr>
                <tr>
                  <th scope="row">Search</th>
                  <td>25%</td>
                  <td>1,250</td>
                </tr>
              </tbody>
            </table>
          </div>

          {/* Loading state */}
          {loading && (
            <div role="status" aria-live="polite">
              <span className="sr-only">Loading analytics data...</span>
              <div aria-hidden="true">Loading...</div>
            </div>
          )}
        </div>
      );
    };

    const { container } = render(<AnalyticsWidget />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();
    
    // Test radio group navigation
    const timeRangeOptions = screen.getAllByRole('radio');
    expect(timeRangeOptions).toHaveLength(3);
    
    timeRangeOptions[0].focus();
    expect(timeRangeOptions[0]).toHaveFocus();
    
    await userEvent.keyboard('{ArrowDown}');
    expect(timeRangeOptions[1]).toHaveFocus();
  });

  it('should have accessible data table widget with sorting', async () => {
    const DataTableWidget = () => {
      const [sortColumn, setSortColumn] = React.useState('name');
      const [sortDirection, setSortDirection] = React.useState<'asc' | 'desc'>('asc');
      
      const handleSort = (column: string) => {
        if (column === sortColumn) {
          setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc');
        } else {
          setSortColumn(column);
          setSortDirection('asc');
        }
      };
      
      const data = [
        { id: 1, name: 'Campaign A', status: 'Active', budget: 5000, performance: 85 },
        { id: 2, name: 'Campaign B', status: 'Paused', budget: 3000, performance: 92 },
        { id: 3, name: 'Campaign C', status: 'Active', budget: 7500, performance: 78 }
      ];
      
      return (
        <div role="region" aria-labelledby="table-title">
          <h2 id="table-title">Campaign Overview</h2>
          
          <table role="table" aria-labelledby="table-title" aria-describedby="table-desc">
            <caption id="table-desc">Campaign data with sortable columns</caption>
            <thead>
              <tr>
                <th scope="col">
                  <button
                    onClick={() => handleSort('name')}
                    aria-sort={sortColumn === 'name' ? sortDirection : 'none'}
                    aria-label={`Sort by campaign name ${sortColumn === 'name' ? sortDirection : ''}`}
                  >
                    Campaign Name
                    <span aria-hidden="true">
                      {sortColumn === 'name' && (sortDirection === 'asc' ? ' ↑' : ' ↓')}
                    </span>
                  </button>
                </th>
                <th scope="col">
                  <button
                    onClick={() => handleSort('status')}
                    aria-sort={sortColumn === 'status' ? sortDirection : 'none'}
                    aria-label={`Sort by status ${sortColumn === 'status' ? sortDirection : ''}`}
                  >
                    Status
                    <span aria-hidden="true">
                      {sortColumn === 'status' && (sortDirection === 'asc' ? ' ↑' : ' ↓')}
                    </span>
                  </button>
                </th>
                <th scope="col">
                  <button
                    onClick={() => handleSort('budget')}
                    aria-sort={sortColumn === 'budget' ? sortDirection : 'none'}
                    aria-label={`Sort by budget ${sortColumn === 'budget' ? sortDirection : ''}`}
                  >
                    Budget
                    <span aria-hidden="true">
                      {sortColumn === 'budget' && (sortDirection === 'asc' ? ' ↑' : ' ↓')}
                    </span>
                  </button>
                </th>
                <th scope="col">
                  <button
                    onClick={() => handleSort('performance')}
                    aria-sort={sortColumn === 'performance' ? sortDirection : 'none'}
                    aria-label={`Sort by performance ${sortColumn === 'performance' ? sortDirection : ''}`}
                  >
                    Performance Score
                    <span aria-hidden="true">
                      {sortColumn === 'performance' && (sortDirection === 'asc' ? ' ↑' : ' ↓')}
                    </span>
                  </button>
                </th>
                <th scope="col">Actions</th>
              </tr>
            </thead>
            <tbody>
              {data.map((campaign) => (
                <tr key={campaign.id}>
                  <th scope="row">{campaign.name}</th>
                  <td>
                    <span 
                      className={`status-badge ${campaign.status.toLowerCase()}`}
                      aria-label={`Status: ${campaign.status}`}
                    >
                      {campaign.status}
                    </span>
                  </td>
                  <td aria-label={`Budget: $${campaign.budget.toLocaleString()}`}>
                    ${campaign.budget.toLocaleString()}
                  </td>
                  <td>
                    <div role="progressbar" 
                         aria-valuenow={campaign.performance} 
                         aria-valuemin={0} 
                         aria-valuemax={100}
                         aria-label={`Performance score: ${campaign.performance} out of 100`}>
                      <div 
                        style={{ 
                          width: `${campaign.performance}%`, 
                          height: '20px', 
                          backgroundColor: campaign.performance >= 80 ? '#28a745' : 
                                          campaign.performance >= 60 ? '#ffc107' : '#dc3545'
                        }}
                        aria-hidden="true"
                      />
                      <span className="sr-only">{campaign.performance}%</span>
                    </div>
                  </td>
                  <td>
                    <div role="group" aria-label={`Actions for ${campaign.name}`}>
                      <button 
                        type="button"
                        aria-label={`Edit ${campaign.name}`}
                      >
                        Edit
                      </button>
                      <button 
                        type="button"
                        aria-label={`View details for ${campaign.name}`}
                      >
                        View
                      </button>
                      <button 
                        type="button"
                        aria-label={`Delete ${campaign.name}`}
                        onClick={() => confirm(`Are you sure you want to delete ${campaign.name}?`)}
                      >
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          
          {/* Pagination */}
          <nav aria-label="Table pagination">
            <ul role="list">
              <li>
                <button disabled aria-label="Go to previous page">Previous</button>
              </li>
              <li>
                <button aria-current="page" aria-label="Current page, page 1">1</button>
              </li>
              <li>
                <button aria-label="Go to page 2">2</button>
              </li>
              <li>
                <button aria-label="Go to page 3">3</button>
              </li>
              <li>
                <button aria-label="Go to next page">Next</button>
              </li>
            </ul>
          </nav>
        </div>
      );
    };

    const { container } = render(<DataTableWidget />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();
    
    // Test sorting functionality
    const nameSort = screen.getByRole('button', { name: /sort by campaign name/i });
    await userEvent.click(nameSort);
    expect(nameSort).toHaveAttribute('aria-sort', 'asc');
    
    await userEvent.click(nameSort);
    expect(nameSort).toHaveAttribute('aria-sort', 'desc');
    
    // Test action buttons
    const editButtons = screen.getAllByRole('button', { name: /edit/i });
    expect(editButtons).toHaveLength(3);
    
    editButtons[0].focus();
    expect(editButtons[0]).toHaveFocus();
  });

  it('should handle widget focus management and keyboard navigation', async () => {
    const InteractiveWidget = () => {
      const [expanded, setExpanded] = React.useState(false);
      const [selectedMetric, setSelectedMetric] = React.useState('impressions');
      
      return (
        <div role="region" aria-labelledby="interactive-title">
          <h2 id="interactive-title">Interactive Metrics</h2>
          
          {/* Expandable section */}
          <div>
            <button
              aria-expanded={expanded}
              aria-controls="metric-details"
              onClick={() => setExpanded(!expanded)}
            >
              {expanded ? 'Hide' : 'Show'} Metric Details
            </button>
            
            <div id="metric-details" hidden={!expanded}>
              <p>Detailed metric information and controls</p>
              
              {/* Tab panel for different metrics */}
              <div role="tablist" aria-label="Metric types">
                <button
                  role="tab"
                  aria-selected={selectedMetric === 'impressions'}
                  aria-controls="impressions-panel"
                  id="impressions-tab"
                  tabIndex={selectedMetric === 'impressions' ? 0 : -1}
                  onClick={() => setSelectedMetric('impressions')}
                >
                  Impressions
                </button>
                <button
                  role="tab"
                  aria-selected={selectedMetric === 'clicks'}
                  aria-controls="clicks-panel"
                  id="clicks-tab"
                  tabIndex={selectedMetric === 'clicks' ? 0 : -1}
                  onClick={() => setSelectedMetric('clicks')}
                >
                  Clicks
                </button>
                <button
                  role="tab"
                  aria-selected={selectedMetric === 'conversions'}
                  aria-controls="conversions-panel"
                  id="conversions-tab"
                  tabIndex={selectedMetric === 'conversions' ? 0 : -1}
                  onClick={() => setSelectedMetric('conversions')}
                >
                  Conversions
                </button>
              </div>
              
              <div
                role="tabpanel"
                aria-labelledby="impressions-tab"
                id="impressions-panel"
                hidden={selectedMetric !== 'impressions'}
              >
                <h3>Impressions Data</h3>
                <p>Total impressions: 125,000</p>
              </div>
              
              <div
                role="tabpanel"
                aria-labelledby="clicks-tab"
                id="clicks-panel"
                hidden={selectedMetric !== 'clicks'}
              >
                <h3>Clicks Data</h3>
                <p>Total clicks: 3,200</p>
              </div>
              
              <div
                role="tabpanel"
                aria-labelledby="conversions-tab"
                id="conversions-panel"
                hidden={selectedMetric !== 'conversions'}
              >
                <h3>Conversions Data</h3>
                <p>Total conversions: 156</p>
              </div>
            </div>
          </div>
          
          {/* Widget controls */}
          <div role="toolbar" aria-label="Widget controls">
            <button type="button" aria-pressed="false">
              <span aria-hidden="true">📌</span>
              Pin Widget
            </button>
            <button type="button">
              <span aria-hidden="true">⚙️</span>
              Settings
            </button>
            <button type="button">
              <span aria-hidden="true">↗️</span>
              Fullscreen
            </button>
          </div>
        </div>
      );
    };

    const { container } = render(<InteractiveWidget />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();
    
    // Test expandable content
    const expandButton = screen.getByRole('button', { name: /show metric details/i });
    expect(expandButton).toHaveAttribute('aria-expanded', 'false');
    
    await userEvent.click(expandButton);
    expect(expandButton).toHaveAttribute('aria-expanded', 'true');
    
    // Test tab navigation
    const impressionsTab = screen.getByRole('tab', { name: 'Impressions' });
    const clicksTab = screen.getByRole('tab', { name: 'Clicks' });
    
    impressionsTab.focus();
    expect(impressionsTab).toHaveFocus();
    expect(impressionsTab).toHaveAttribute('aria-selected', 'true');
    
    await userEvent.keyboard('{ArrowRight}');
    expect(clicksTab).toHaveFocus();
    
    await userEvent.keyboard('{Enter}');
    expect(clicksTab).toHaveAttribute('aria-selected', 'true');
  });
});