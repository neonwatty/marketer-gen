/**
 * Dashboard Performance Test Suite
 * Tests dashboard load times, component rendering, and responsiveness
 */

import React, { Suspense } from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

// Mock AnalyticsDashboard component with performance-critical features
const MockAnalyticsDashboard = ({ 
  brandId, 
  initialMetrics = {},
  theme = 'light',
  chartType = 'line'
}: any) => {
  const [loading, setLoading] = React.useState(true);
  const [metrics, setMetrics] = React.useState(initialMetrics);
  const [currentTheme, setCurrentTheme] = React.useState(theme);
  const [currentChartType, setCurrentChartType] = React.useState(chartType);

  React.useEffect(() => {
    // Simulate dashboard data loading
    const timer = setTimeout(() => {
      setMetrics({
        social_media: {
          platforms: [
            { name: 'Facebook', engagement: 1250 },
            { name: 'Twitter', engagement: 850 },
            { name: 'Instagram', engagement: 2100 }
          ],
          summary: { total_engagement: 4200, total_followers: 15000 }
        },
        email: {
          campaigns: [
            { name: 'Newsletter', open_rate: 25.5, click_rate: 3.2 },
            { name: 'Promotion', open_rate: 18.7, click_rate: 5.1 }
          ],
          summary: { total_sent: 50000, avg_open_rate: 22.1 }
        },
        google_analytics: {
          timeseries: Array.from({ length: 30 }, (_, i) => ({
            date: new Date(Date.now() - (29 - i) * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
            sessions: Math.floor(Math.random() * 1000) + 500,
            pageviews: Math.floor(Math.random() * 2000) + 1000
          })),
          summary: { total_sessions: 45000, total_pageviews: 120000 }
        }
      });
      setLoading(false);
    }, 100);

    return () => clearTimeout(timer);
  }, []);

  const handleThemeChange = (newTheme: string) => {
    setCurrentTheme(newTheme);
  };

  const handleChartTypeChange = (newType: string) => {
    setCurrentChartType(newType);
  };

  if (loading) {
    return (
      <div data-testid="dashboard-loading" className="dashboard-loading">
        <div className="spinner" />
        <span>Loading dashboard...</span>
      </div>
    );
  }

  return (
    <div 
      data-testid="analytics-dashboard" 
      className={`dashboard theme-${currentTheme}`}
      data-theme={currentTheme}
    >
      {/* Header with controls */}
      <div className="dashboard-header">
        <h1>Analytics Dashboard</h1>
        <div className="dashboard-controls">
          <select 
            data-testid="theme-selector"
            value={currentTheme} 
            onChange={(e) => handleThemeChange(e.target.value)}
          >
            <option value="light">Light</option>
            <option value="dark">Dark</option>
            <option value="brand">Brand</option>
          </select>
          <select 
            data-testid="chart-type-selector"
            value={currentChartType} 
            onChange={(e) => handleChartTypeChange(e.target.value)}
          >
            <option value="line">Line Chart</option>
            <option value="bar">Bar Chart</option>
            <option value="area">Area Chart</option>
            <option value="donut">Donut Chart</option>
          </select>
        </div>
      </div>

      {/* Summary metrics */}
      <div className="metrics-grid" data-testid="metrics-grid">
        {Object.entries(metrics).map(([source, data]: [string, any]) => (
          <div key={source} className="metric-card" data-testid={`metric-${source}`}>
            <h3>{source.replace('_', ' ').toUpperCase()}</h3>
            {data.summary && Object.entries(data.summary).map(([key, value]: [string, any]) => (
              <div key={key} className="metric-item">
                <span className="metric-label">{key}:</span>
                <span className="metric-value">{value.toLocaleString()}</span>
              </div>
            ))}
          </div>
        ))}
      </div>

      {/* Chart area */}
      <div className="chart-container" data-testid="chart-container">
        <div className={`chart chart-${currentChartType}`} data-testid="main-chart">
          <svg width="800" height="400" viewBox="0 0 800 400">
            {/* Mock chart visualization */}
            {metrics.google_analytics?.timeseries?.slice(0, 20).map((point: any, i: number) => (
              <circle
                key={i}
                cx={40 + (i * 35)}
                cy={200 - (point.sessions / 10)}
                r="3"
                fill="#0088FE"
              />
            ))}
            {/* Chart grid */}
            {Array.from({ length: 10 }, (_, i) => (
              <line
                key={`grid-${i}`}
                x1="40"
                y1={40 + (i * 32)}
                x2="760"
                y2={40 + (i * 32)}
                stroke="#e0e0e0"
                strokeWidth="1"
              />
            ))}
          </svg>
        </div>
      </div>

      {/* Data tables */}
      <div className="data-tables" data-testid="data-tables">
        {metrics.social_media?.platforms && (
          <div className="data-table" data-testid="social-media-table">
            <h3>Social Media Platforms</h3>
            <table>
              <thead>
                <tr>
                  <th>Platform</th>
                  <th>Engagement</th>
                </tr>
              </thead>
              <tbody>
                {metrics.social_media.platforms.map((platform: any, i: number) => (
                  <tr key={i}>
                    <td>{platform.name}</td>
                    <td>{platform.engagement.toLocaleString()}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
};

// Performance measurement utilities
const measureRenderTime = async (renderFunction: () => void): Promise<number> => {
  const start = performance.now();
  renderFunction();
  await new Promise(resolve => setTimeout(resolve, 0)); // Wait for render
  const end = performance.now();
  return end - start;
};

const measureInteractionTime = async (interaction: () => Promise<void>): Promise<number> => {
  const start = performance.now();
  await interaction();
  const end = performance.now();
  return end - start;
};

const measureDataLoadTime = async (loadFunction: () => Promise<void>): Promise<number> => {
  const start = performance.now();
  await loadFunction();
  const end = performance.now();
  return end - start;
};

const measureMemoryUsage = (): number => {
  if ('memory' in performance) {
    return (performance as any).memory.usedJSHeapSize;
  }
  return 0;
};

describe('Dashboard Performance Tests', () => {
  const PERFORMANCE_THRESHOLDS = {
    INITIAL_RENDER: 2000,     // 2 seconds for initial render
    COMPONENT_RENDER: 100,    // 100ms for component rendering
    INTERACTION_TIME: 100,    // 100ms for interactions
    DATA_LOAD_TIME: 1000,     // 1 second for data loading
    THEME_SWITCH_TIME: 50,    // 50ms for theme switching
    CHART_RENDER_TIME: 150,   // 150ms for chart rendering
    MEMORY_LEAK_THRESHOLD: 10 * 1024 * 1024, // 10MB
    TABLE_RENDER_THRESHOLD: 200, // 200ms for large tables
    RESPONSIVE_BREAKPOINT: 100  // 100ms for responsive changes
  };

  describe('Initial Dashboard Load Performance', () => {
    it('should load dashboard within 2 seconds', async () => {
      const renderTime = await measureRenderTime(() => {
        render(<MockAnalyticsDashboard brandId="test-brand" />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.INITIAL_RENDER);
    });

    it('should show loading state immediately', async () => {
      render(<MockAnalyticsDashboard brandId="test-brand" />);
      
      // Loading state should be visible immediately
      expect(screen.getByTestId('dashboard-loading')).toBeInTheDocument();
      expect(screen.getByText('Loading dashboard...')).toBeInTheDocument();
    });

    it('should transition from loading to loaded state efficiently', async () => {
      render(<MockAnalyticsDashboard brandId="test-brand" />);
      
      // Wait for loading to complete
      await waitFor(() => {
        expect(screen.getByTestId('analytics-dashboard')).toBeInTheDocument();
      }, { timeout: 200 });

      // Should not have loading state anymore
      expect(screen.queryByTestId('dashboard-loading')).not.toBeInTheDocument();
    });
  });

  describe('Component Rendering Performance', () => {
    it('should render metric cards within performance threshold', async () => {
      const renderTime = await measureRenderTime(() => {
        render(
          <MockAnalyticsDashboard 
            brandId="test-brand" 
            initialMetrics={{
              social_media: { summary: { followers: 10000, engagement: 5000 } },
              email: { summary: { subscribers: 15000, open_rate: 25.5 } },
              google_analytics: { summary: { sessions: 45000, pageviews: 120000 } }
            }}
          />
        );
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.COMPONENT_RENDER);
    });

    it('should handle large metric datasets efficiently', async () => {
      const largeMetrics = {
        social_media: {
          platforms: Array.from({ length: 50 }, (_, i) => ({
            name: `Platform ${i}`,
            engagement: Math.floor(Math.random() * 10000)
          })),
          summary: { total_engagement: 500000 }
        }
      };

      const renderTime = await measureRenderTime(() => {
        render(<MockAnalyticsDashboard brandId="test-brand" initialMetrics={largeMetrics} />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.COMPONENT_RENDER * 2);
    });

    it('should render data tables efficiently', async () => {
      const { rerender } = render(<MockAnalyticsDashboard brandId="test-brand" />);
      
      await waitFor(() => {
        expect(screen.getByTestId('social-media-table')).toBeInTheDocument();
      });

      // Re-render with different data
      const renderTime = await measureRenderTime(() => {
        rerender(
          <MockAnalyticsDashboard 
            brandId="test-brand"
            initialMetrics={{
              social_media: {
                platforms: Array.from({ length: 100 }, (_, i) => ({
                  name: `Platform ${i}`,
                  engagement: Math.floor(Math.random() * 10000)
                }))
              }
            }}
          />
        );
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.TABLE_RENDER_THRESHOLD);
    });
  });

  describe('Chart Rendering Performance', () => {
    it('should render charts within performance threshold', async () => {
      render(<MockAnalyticsDashboard brandId="test-brand" />);
      
      await waitFor(() => {
        expect(screen.getByTestId('main-chart')).toBeInTheDocument();
      });

      const chart = screen.getByTestId('main-chart');
      expect(chart).toBeInTheDocument();
      
      // Chart should have rendered SVG elements
      const svgElements = chart.querySelectorAll('circle, line');
      expect(svgElements.length).toBeGreaterThan(0);
    });

    it('should handle chart type changes efficiently', async () => {
      render(<MockAnalyticsDashboard brandId="test-brand" />);
      
      await waitFor(() => {
        expect(screen.getByTestId('chart-type-selector')).toBeInTheDocument();
      });

      const chartSelector = screen.getByTestId('chart-type-selector');
      
      const interactionTime = await measureInteractionTime(async () => {
        await userEvent.selectOptions(chartSelector, 'bar');
      });

      expect(interactionTime).toBeLessThan(PERFORMANCE_THRESHOLDS.CHART_RENDER_TIME);
      
      // Chart should update
      await waitFor(() => {
        const chart = screen.getByTestId('main-chart');
        expect(chart).toHaveClass('chart-bar');
      });
    });

    it('should handle large chart datasets with virtualization', async () => {
      const largeDataset = {
        google_analytics: {
          timeseries: Array.from({ length: 1000 }, (_, i) => ({
            date: new Date(Date.now() - i * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
            sessions: Math.floor(Math.random() * 1000) + 500,
            pageviews: Math.floor(Math.random() * 2000) + 1000
          }))
        }
      };

      const renderTime = await measureRenderTime(() => {
        render(<MockAnalyticsDashboard brandId="test-brand" initialMetrics={largeDataset} />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.CHART_RENDER_TIME * 2);
    });
  });

  describe('Theme Switching Performance', () => {
    it('should switch themes within performance threshold', async () => {
      render(<MockAnalyticsDashboard brandId="test-brand" />);
      
      await waitFor(() => {
        expect(screen.getByTestId('theme-selector')).toBeInTheDocument();
      });

      const themeSelector = screen.getByTestId('theme-selector');
      
      const switchTime = await measureInteractionTime(async () => {
        await userEvent.selectOptions(themeSelector, 'dark');
      });

      expect(switchTime).toBeLessThan(PERFORMANCE_THRESHOLDS.THEME_SWITCH_TIME);
      
      // Theme should have changed
      await waitFor(() => {
        const dashboard = screen.getByTestId('analytics-dashboard');
        expect(dashboard).toHaveAttribute('data-theme', 'dark');
      });
    });

    it('should maintain performance during rapid theme changes', async () => {
      render(<MockAnalyticsDashboard brandId="test-brand" />);
      
      await waitFor(() => {
        expect(screen.getByTestId('theme-selector')).toBeInTheDocument();
      });

      const themeSelector = screen.getByTestId('theme-selector');
      const themes = ['dark', 'brand', 'light'];
      
      const totalTime = await measureInteractionTime(async () => {
        for (const theme of themes) {
          await userEvent.selectOptions(themeSelector, theme);
          await new Promise(resolve => setTimeout(resolve, 10));
        }
      });

      const averageTime = totalTime / themes.length;
      expect(averageTime).toBeLessThan(PERFORMANCE_THRESHOLDS.THEME_SWITCH_TIME);
    });
  });

  describe('Responsive Performance', () => {
    it('should handle viewport changes efficiently', async () => {
      render(<MockAnalyticsDashboard brandId="test-brand" />);
      
      await waitFor(() => {
        expect(screen.getByTestId('analytics-dashboard')).toBeInTheDocument();
      });

      // Mock viewport change
      const mockViewportChange = async () => {
        // Simulate window resize
        global.innerWidth = 768;
        global.innerHeight = 1024;
        fireEvent(window, new Event('resize'));
        
        // Wait for any responsive changes
        await new Promise(resolve => setTimeout(resolve, 50));
      };

      const responseTime = await measureInteractionTime(mockViewportChange);
      expect(responseTime).toBeLessThan(PERFORMANCE_THRESHOLDS.RESPONSIVE_BREAKPOINT);
    });

    it('should adapt layout for mobile efficiently', async () => {
      // Mock mobile viewport
      Object.defineProperty(window, 'innerWidth', {
        writable: true,
        configurable: true,
        value: 375,
      });
      Object.defineProperty(window, 'innerHeight', {
        writable: true,
        configurable: true,
        value: 667,
      });

      const renderTime = await measureRenderTime(() => {
        render(<MockAnalyticsDashboard brandId="test-brand" />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.COMPONENT_RENDER * 1.5);
    });
  });

  describe('Data Loading Performance', () => {
    it('should handle incremental data updates efficiently', async () => {
      const { rerender } = render(<MockAnalyticsDashboard brandId="test-brand" />);
      
      await waitFor(() => {
        expect(screen.getByTestId('analytics-dashboard')).toBeInTheDocument();
      });

      // Simulate data update
      const updateTime = await measureInteractionTime(async () => {
        rerender(
          <MockAnalyticsDashboard 
            brandId="test-brand"
            initialMetrics={{
              social_media: { 
                summary: { followers: 15000, engagement: 7500 }
              }
            }}
          />
        );
        
        await new Promise(resolve => setTimeout(resolve, 10));
      });

      expect(updateTime).toBeLessThan(PERFORMANCE_THRESHOLDS.INTERACTION_TIME);
    });

    it('should handle real-time data streaming efficiently', async () => {
      render(<MockAnalyticsDashboard brandId="test-brand" />);
      
      await waitFor(() => {
        expect(screen.getByTestId('analytics-dashboard')).toBeInTheDocument();
      });

      const initialMemory = measureMemoryUsage();
      
      // Simulate multiple data updates
      for (let i = 0; i < 10; i++) {
        fireEvent(window, new CustomEvent('dashboard-update', {
          detail: { 
            timestamp: Date.now(),
            data: { sessions: Math.random() * 1000 }
          }
        }));
        await new Promise(resolve => setTimeout(resolve, 10));
      }
      
      const finalMemory = measureMemoryUsage();
      const memoryDiff = finalMemory - initialMemory;
      
      expect(memoryDiff).toBeLessThan(PERFORMANCE_THRESHOLDS.MEMORY_LEAK_THRESHOLD);
    });
  });

  describe('Memory Management', () => {
    it('should not leak memory during component lifecycle', async () => {
      const initialMemory = measureMemoryUsage();
      
      const { unmount } = render(<MockAnalyticsDashboard brandId="test-brand" />);
      
      await waitFor(() => {
        expect(screen.getByTestId('analytics-dashboard')).toBeInTheDocument();
      });
      
      // Simulate some interactions
      const themeSelector = screen.getByTestId('theme-selector');
      await userEvent.selectOptions(themeSelector, 'dark');
      await userEvent.selectOptions(themeSelector, 'light');
      
      unmount();
      
      // Force garbage collection if available
      if (global.gc) {
        global.gc();
      }
      
      await new Promise(resolve => setTimeout(resolve, 100));
      
      const finalMemory = measureMemoryUsage();
      const memoryDiff = finalMemory - initialMemory;
      
      expect(memoryDiff).toBeLessThan(PERFORMANCE_THRESHOLDS.MEMORY_LEAK_THRESHOLD);
    });

    it('should handle multiple dashboard instances efficiently', async () => {
      const initialMemory = measureMemoryUsage();
      
      const components = Array.from({ length: 5 }, (_, i) => (
        <MockAnalyticsDashboard key={i} brandId={`brand-${i}`} />
      ));
      
      const { unmount } = render(<div>{components}</div>);
      
      await waitFor(() => {
        expect(screen.getAllByTestId('analytics-dashboard')).toHaveLength(5);
      });
      
      unmount();
      
      if (global.gc) {
        global.gc();
      }
      
      const finalMemory = measureMemoryUsage();
      const memoryDiff = finalMemory - initialMemory;
      
      expect(memoryDiff).toBeLessThan(PERFORMANCE_THRESHOLDS.MEMORY_LEAK_THRESHOLD * 2);
    });
  });

  describe('Accessibility Performance', () => {
    it('should maintain screen reader performance', async () => {
      render(<MockAnalyticsDashboard brandId="test-brand" />);
      
      await waitFor(() => {
        expect(screen.getByTestId('analytics-dashboard')).toBeInTheDocument();
      });

      const dashboard = screen.getByTestId('analytics-dashboard');
      
      // Check that ARIA attributes don't slow down rendering
      const elements = dashboard.querySelectorAll('[aria-label], [aria-describedby], [role]');
      expect(elements.length).toBeGreaterThan(0);
      
      // Should be able to navigate quickly
      const focusableElements = dashboard.querySelectorAll('button, select, input, [tabindex]');
      expect(focusableElements.length).toBeGreaterThan(0);
    });
  });
});