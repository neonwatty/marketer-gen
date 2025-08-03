/**
 * Analytics Chart Rendering Performance Test Suite
 * Tests chart rendering speed, memory usage, and optimization
 */

import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

// Mock chart data interfaces
interface ChartDataPoint {
  name: string;
  value: number;
  date?: string;
  x?: number;
  y?: number;
  category?: string;
}

interface ChartProps {
  data: ChartDataPoint[];
  width?: number;
  height?: number;
  animated?: boolean;
  responsive?: boolean;
  onDataPointClick?: (point: ChartDataPoint) => void;
  theme?: 'light' | 'dark';
  showTooltip?: boolean;
  showLegend?: boolean;
}

// Mock Chart Components
const MockLineChart: React.FC<ChartProps> = ({ 
  data, 
  width = 800, 
  height = 400, 
  animated = true,
  onDataPointClick,
  theme = 'light',
  showTooltip = true,
  showLegend = true
}) => {
  const [hoveredPoint, setHoveredPoint] = React.useState<number | null>(null);
  const [animationComplete, setAnimationComplete] = React.useState(!animated);

  React.useEffect(() => {
    if (animated) {
      const timer = setTimeout(() => setAnimationComplete(true), 500);
      return () => clearTimeout(timer);
    }
  }, [animated]);

  const handlePointClick = (point: ChartDataPoint, index: number) => {
    onDataPointClick?.(point);
  };

  const handlePointHover = (index: number | null) => {
    setHoveredPoint(index);
  };

  return (
    <div 
      className={`line-chart theme-${theme}`} 
      data-testid="line-chart"
      style={{ width, height }}
    >
      <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`}>
        {/* Grid lines */}
        {Array.from({ length: 10 }, (_, i) => (
          <line
            key={`grid-${i}`}
            x1="50"
            y1={50 + (i * (height - 100) / 9)}
            x2={width - 50}
            y2={50 + (i * (height - 100) / 9)}
            stroke={theme === 'dark' ? '#374151' : '#e5e7eb'}
            strokeWidth="1"
          />
        ))}
        
        {/* Chart line */}
        <path
          d={data.map((point, i) => {
            const x = 50 + (i * (width - 100) / (data.length - 1));
            const y = height - 50 - (point.value / Math.max(...data.map(p => p.value))) * (height - 100);
            return `${i === 0 ? 'M' : 'L'} ${x} ${y}`;
          }).join(' ')}
          fill="none"
          stroke="#0088FE"
          strokeWidth="2"
          opacity={animationComplete ? 1 : 0.3}
          style={{
            transition: animated ? 'opacity 0.5s ease-in-out' : 'none'
          }}
        />
        
        {/* Data points */}
        {data.map((point, i) => {
          const x = 50 + (i * (width - 100) / (data.length - 1));
          const y = height - 50 - (point.value / Math.max(...data.map(p => p.value))) * (height - 100);
          
          return (
            <circle
              key={i}
              cx={x}
              cy={y}
              r={hoveredPoint === i ? 6 : 4}
              fill="#0088FE"
              onClick={() => handlePointClick(point, i)}
              onMouseEnter={() => handlePointHover(i)}
              onMouseLeave={() => handlePointHover(null)}
              style={{ 
                cursor: 'pointer',
                transition: animated ? 'r 0.2s ease' : 'none'
              }}
              data-testid={`data-point-${i}`}
            />
          );
        })}
      </svg>
      
      {/* Tooltip */}
      {showTooltip && hoveredPoint !== null && (
        <div 
          className="chart-tooltip"
          data-testid="chart-tooltip"
          style={{
            position: 'absolute',
            background: theme === 'dark' ? '#1f2937' : 'white',
            color: theme === 'dark' ? 'white' : 'black',
            padding: '8px',
            border: '1px solid #ccc',
            borderRadius: '4px',
            pointerEvents: 'none'
          }}
        >
          <div>Value: {data[hoveredPoint].value}</div>
          <div>Name: {data[hoveredPoint].name}</div>
        </div>
      )}
      
      {/* Legend */}
      {showLegend && (
        <div className="chart-legend" data-testid="chart-legend">
          <div className="legend-item">
            <div 
              className="legend-color" 
              style={{ 
                width: '12px', 
                height: '12px', 
                backgroundColor: '#0088FE',
                display: 'inline-block',
                marginRight: '8px'
              }}
            />
            Data Series
          </div>
        </div>
      )}
    </div>
  );
};

const MockBarChart: React.FC<ChartProps> = ({ 
  data, 
  width = 800, 
  height = 400, 
  animated = true,
  onDataPointClick,
  theme = 'light'
}) => {
  const [animationProgress, setAnimationProgress] = React.useState(animated ? 0 : 1);

  React.useEffect(() => {
    if (animated) {
      const duration = 1000;
      const steps = 60;
      const stepDuration = duration / steps;
      let currentStep = 0;

      const timer = setInterval(() => {
        currentStep++;
        setAnimationProgress(currentStep / steps);
        if (currentStep >= steps) {
          clearInterval(timer);
        }
      }, stepDuration);

      return () => clearInterval(timer);
    }
  }, [animated]);

  const maxValue = Math.max(...data.map(p => p.value));

  return (
    <div 
      className={`bar-chart theme-${theme}`} 
      data-testid="bar-chart"
      style={{ width, height }}
    >
      <svg width={width} height={height}>
        {data.map((point, i) => {
          const barWidth = (width - 100) / data.length * 0.8;
          const barHeight = (point.value / maxValue) * (height - 100) * animationProgress;
          const x = 50 + (i * (width - 100) / data.length) + ((width - 100) / data.length - barWidth) / 2;
          const y = height - 50 - barHeight;

          return (
            <rect
              key={i}
              x={x}
              y={y}
              width={barWidth}
              height={barHeight}
              fill="#00C49F"
              onClick={() => onDataPointClick?.(point)}
              style={{ cursor: 'pointer' }}
              data-testid={`bar-${i}`}
            />
          );
        })}
      </svg>
    </div>
  );
};

const MockPieChart: React.FC<ChartProps> = ({ 
  data, 
  width = 400, 
  height = 400, 
  animated = true,
  onDataPointClick,
  theme = 'light'
}) => {
  const [animationProgress, setAnimationProgress] = React.useState(animated ? 0 : 1);
  const total = data.reduce((sum, point) => sum + point.value, 0);
  const centerX = width / 2;
  const centerY = height / 2;
  const radius = Math.min(width, height) / 2 - 20;

  React.useEffect(() => {
    if (animated) {
      const timer = setTimeout(() => setAnimationProgress(1), 800);
      return () => clearTimeout(timer);
    }
  }, [animated]);

  let cumulativePercentage = 0;
  const colors = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884D8', '#82CA9D'];

  return (
    <div 
      className={`pie-chart theme-${theme}`} 
      data-testid="pie-chart"
      style={{ width, height }}
    >
      <svg width={width} height={height}>
        {data.map((point, i) => {
          const percentage = point.value / total;
          const startAngle = cumulativePercentage * 2 * Math.PI;
          const endAngle = (cumulativePercentage + percentage) * 2 * Math.PI * animationProgress;
          
          const largeArc = endAngle - startAngle > Math.PI ? 1 : 0;
          const x1 = centerX + radius * Math.cos(startAngle);
          const y1 = centerY + radius * Math.sin(startAngle);
          const x2 = centerX + radius * Math.cos(endAngle);
          const y2 = centerY + radius * Math.sin(endAngle);

          const pathData = [
            `M ${centerX} ${centerY}`,
            `L ${x1} ${y1}`,
            `A ${radius} ${radius} 0 ${largeArc} 1 ${x2} ${y2}`,
            'Z'
          ].join(' ');

          cumulativePercentage += percentage;

          return (
            <path
              key={i}
              d={pathData}
              fill={colors[i % colors.length]}
              onClick={() => onDataPointClick?.(point)}
              style={{ cursor: 'pointer' }}
              data-testid={`pie-slice-${i}`}
            />
          );
        })}
      </svg>
    </div>
  );
};

const MockHeatmapChart: React.FC<{
  data: Array<{ row: number; col: number; value: number; label?: string }>;
  width?: number;
  height?: number;
  theme?: 'light' | 'dark';
}> = ({ data, width = 600, height = 400, theme = 'light' }) => {
  const maxRow = Math.max(...data.map(d => d.row));
  const maxCol = Math.max(...data.map(d => d.col));
  const maxValue = Math.max(...data.map(d => d.value));
  
  const cellWidth = (width - 40) / (maxCol + 1);
  const cellHeight = (height - 40) / (maxRow + 1);

  return (
    <div 
      className={`heatmap-chart theme-${theme}`} 
      data-testid="heatmap-chart"
      style={{ width, height }}
    >
      <svg width={width} height={height}>
        {data.map((point, i) => {
          const intensity = point.value / maxValue;
          const opacity = 0.1 + (0.9 * intensity);
          
          return (
            <rect
              key={i}
              x={20 + point.col * cellWidth}
              y={20 + point.row * cellHeight}
              width={cellWidth - 1}
              height={cellHeight - 1}
              fill="#0088FE"
              opacity={opacity}
              data-testid={`heatmap-cell-${i}`}
            />
          );
        })}
      </svg>
    </div>
  );
};

// Mock Complex Dashboard with Multiple Charts
const MockAnalyticsDashboard: React.FC<{
  datasets: Record<string, ChartDataPoint[]>;
  chartTypes?: Record<string, string>;
  theme?: 'light' | 'dark';
  animated?: boolean;
}> = ({ datasets, chartTypes = {}, theme = 'light', animated = true }) => {
  const [selectedChart, setSelectedChart] = React.useState<string | null>(null);
  const [isLoading, setIsLoading] = React.useState(true);

  React.useEffect(() => {
    const timer = setTimeout(() => setIsLoading(false), 200);
    return () => clearTimeout(timer);
  }, []);

  if (isLoading) {
    return (
      <div data-testid="dashboard-loading" className="loading-dashboard">
        <div>Loading charts...</div>
      </div>
    );
  }

  return (
    <div 
      className={`analytics-dashboard theme-${theme}`} 
      data-testid="analytics-dashboard"
    >
      <div className="dashboard-grid">
        {Object.entries(datasets).map(([key, data]) => {
          const chartType = chartTypes[key] || 'line';
          
          return (
            <div 
              key={key} 
              className="chart-container"
              data-testid={`chart-container-${key}`}
              onClick={() => setSelectedChart(selectedChart === key ? null : key)}
            >
              <h3>{key.replace('_', ' ').toUpperCase()}</h3>
              {chartType === 'line' && (
                <MockLineChart 
                  data={data} 
                  theme={theme} 
                  animated={animated}
                  width={400}
                  height={300}
                />
              )}
              {chartType === 'bar' && (
                <MockBarChart 
                  data={data} 
                  theme={theme} 
                  animated={animated}
                  width={400}
                  height={300}
                />
              )}
              {chartType === 'pie' && (
                <MockPieChart 
                  data={data} 
                  theme={theme} 
                  animated={animated}
                  width={300}
                  height={300}
                />
              )}
            </div>
          );
        })}
      </div>
      
      {selectedChart && (
        <div className="chart-detail" data-testid="chart-detail">
          <h2>Detailed View: {selectedChart}</h2>
          <MockLineChart 
            data={datasets[selectedChart]} 
            theme={theme}
            width={800}
            height={600}
            animated={animated}
          />
        </div>
      )}
    </div>
  );
};

// Performance measurement utilities
const measureRenderTime = async (renderFunction: () => void): Promise<number> => {
  const start = performance.now();
  renderFunction();
  await new Promise(resolve => setTimeout(resolve, 0));
  const end = performance.now();
  return end - start;
};

const measureAnimationTime = async (element: HTMLElement, expectedDuration: number): Promise<number> => {
  const start = performance.now();
  
  // Wait for animation to complete
  await new Promise(resolve => setTimeout(resolve, expectedDuration + 100));
  
  const end = performance.now();
  return end - start;
};

const measureMemoryUsage = (): number => {
  if ('memory' in performance) {
    return (performance as any).memory.usedJSHeapSize;
  }
  return 0;
};

const generateChartData = (points: number): ChartDataPoint[] => {
  return Array.from({ length: points }, (_, i) => ({
    name: `Point ${i}`,
    value: Math.floor(Math.random() * 1000) + 100,
    date: new Date(Date.now() - (points - i) * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
    x: i,
    y: Math.floor(Math.random() * 500),
    category: ['A', 'B', 'C'][i % 3]
  }));
};

const generateHeatmapData = (rows: number, cols: number) => {
  const data = [];
  for (let row = 0; row < rows; row++) {
    for (let col = 0; col < cols; col++) {
      data.push({
        row,
        col,
        value: Math.floor(Math.random() * 100),
        label: `${row},${col}`
      });
    }
  }
  return data;
};

describe('Analytics Chart Performance Tests', () => {
  const PERFORMANCE_THRESHOLDS = {
    SIMPLE_CHART_RENDER: 150,    // 150ms for simple charts
    COMPLEX_CHART_RENDER: 300,   // 300ms for complex charts
    LARGE_DATASET_RENDER: 500,   // 500ms for large datasets
    ANIMATION_OVERHEAD: 50,      // 50ms overhead for animations
    CHART_INTERACTION: 50,       // 50ms for interactions
    THEME_SWITCH: 100,          // 100ms for theme switching
    RESPONSIVE_UPDATE: 100,     // 100ms for responsive updates
    TOOLTIP_RESPONSE: 16,       // 16ms for tooltip display (60fps)
    ZOOM_INTERACTION: 100,      // 100ms for zoom operations
    MEMORY_LEAK_THRESHOLD: 20 * 1024 * 1024, // 20MB for charts
    DASHBOARD_RENDER: 1000,     // 1 second for full dashboard
    REAL_TIME_UPDATE: 50       // 50ms for real-time data updates
  };

  describe('Basic Chart Rendering Performance', () => {
    it('should render line chart within performance threshold', async () => {
      const data = generateChartData(50);
      
      const renderTime = await measureRenderTime(() => {
        render(<MockLineChart data={data} animated={false} />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.SIMPLE_CHART_RENDER);
    });

    it('should render bar chart efficiently', async () => {
      const data = generateChartData(30);
      
      const renderTime = await measureRenderTime(() => {
        render(<MockBarChart data={data} animated={false} />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.SIMPLE_CHART_RENDER);
    });

    it('should render pie chart efficiently', async () => {
      const data = generateChartData(8);
      
      const renderTime = await measureRenderTime(() => {
        render(<MockPieChart data={data} animated={false} />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.SIMPLE_CHART_RENDER);
    });

    it('should render heatmap efficiently', async () => {
      const data = generateHeatmapData(10, 24);
      
      const renderTime = await measureRenderTime(() => {
        render(<MockHeatmapChart data={data} />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.COMPLEX_CHART_RENDER);
    });
  });

  describe('Large Dataset Performance', () => {
    it('should handle large line chart datasets', async () => {
      const data = generateChartData(1000);
      
      const renderTime = await measureRenderTime(() => {
        render(<MockLineChart data={data} animated={false} />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.LARGE_DATASET_RENDER);
    });

    it('should handle large bar chart datasets', async () => {
      const data = generateChartData(500);
      
      const renderTime = await measureRenderTime(() => {
        render(<MockBarChart data={data} animated={false} />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.LARGE_DATASET_RENDER);
    });

    it('should handle large heatmap datasets', async () => {
      const data = generateHeatmapData(50, 50); // 2500 cells
      
      const renderTime = await measureRenderTime(() => {
        render(<MockHeatmapChart data={data} />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.LARGE_DATASET_RENDER);
    });

    it('should virtualize extremely large datasets', async () => {
      const data = generateChartData(10000);
      
      const initialMemory = measureMemoryUsage();
      render(<MockLineChart data={data} animated={false} />);
      const finalMemory = measureMemoryUsage();
      
      const memoryUsed = finalMemory - initialMemory;
      expect(memoryUsed).toBeLessThan(PERFORMANCE_THRESHOLDS.MEMORY_LEAK_THRESHOLD);
    });
  });

  describe('Animation Performance', () => {
    it('should complete line chart animation within expected time', async () => {
      const data = generateChartData(50);
      
      render(<MockLineChart data={data} animated={true} />);
      
      const chart = screen.getByTestId('line-chart');
      const animationTime = await measureAnimationTime(chart, 500);
      
      expect(animationTime).toBeLessThan(500 + PERFORMANCE_THRESHOLDS.ANIMATION_OVERHEAD);
    });

    it('should handle bar chart animation efficiently', async () => {
      const data = generateChartData(20);
      
      render(<MockBarChart data={data} animated={true} />);
      
      const chart = screen.getByTestId('bar-chart');
      const animationTime = await measureAnimationTime(chart, 1000);
      
      expect(animationTime).toBeLessThan(1000 + PERFORMANCE_THRESHOLDS.ANIMATION_OVERHEAD);
    });

    it('should handle pie chart animation efficiently', async () => {
      const data = generateChartData(6);
      
      render(<MockPieChart data={data} animated={true} />);
      
      const chart = screen.getByTestId('pie-chart');
      const animationTime = await measureAnimationTime(chart, 800);
      
      expect(animationTime).toBeLessThan(800 + PERFORMANCE_THRESHOLDS.ANIMATION_OVERHEAD);
    });

    it('should disable animations for performance when needed', async () => {
      const data = generateChartData(1000);
      
      const animatedTime = await measureRenderTime(() => {
        render(<MockLineChart data={data} animated={true} />);
      });
      
      const staticTime = await measureRenderTime(() => {
        render(<MockLineChart data={data} animated={false} />);
      });
      
      // Static rendering should be faster
      expect(staticTime).toBeLessThan(animatedTime);
    });
  });

  describe('Chart Interaction Performance', () => {
    it('should handle data point clicks efficiently', async () => {
      const mockClick = jest.fn();
      const data = generateChartData(50);
      
      render(<MockLineChart data={data} onDataPointClick={mockClick} animated={false} />);
      
      const dataPoint = screen.getByTestId('data-point-0');
      
      const start = performance.now();
      fireEvent.click(dataPoint);
      const end = performance.now();
      
      expect(end - start).toBeLessThan(PERFORMANCE_THRESHOLDS.CHART_INTERACTION);
      expect(mockClick).toHaveBeenCalled();
    });

    it('should display tooltips within performance threshold', async () => {
      const data = generateChartData(30);
      
      render(<MockLineChart data={data} showTooltip={true} animated={false} />);
      
      const dataPoint = screen.getByTestId('data-point-5');
      
      const start = performance.now();
      fireEvent.mouseEnter(dataPoint);
      
      await waitFor(() => {
        expect(screen.getByTestId('chart-tooltip')).toBeInTheDocument();
      });
      
      const end = performance.now();
      expect(end - start).toBeLessThan(PERFORMANCE_THRESHOLDS.TOOLTIP_RESPONSE);
    });

    it('should handle rapid hover interactions efficiently', async () => {
      const data = generateChartData(20);
      
      render(<MockLineChart data={data} showTooltip={true} animated={false} />);
      
      const dataPoints = screen.getAllByTestId(/data-point-/);
      
      const start = performance.now();
      
      // Rapid hover over multiple points
      for (let i = 0; i < 10; i++) {
        fireEvent.mouseEnter(dataPoints[i]);
        fireEvent.mouseLeave(dataPoints[i]);
      }
      
      const end = performance.now();
      const avgTime = (end - start) / 10;
      
      expect(avgTime).toBeLessThan(PERFORMANCE_THRESHOLDS.TOOLTIP_RESPONSE);
    });
  });

  describe('Theme Switching Performance', () => {
    it('should switch chart theme efficiently', async () => {
      const data = generateChartData(50);
      const { rerender } = render(<MockLineChart data={data} theme="light" />);
      
      const start = performance.now();
      rerender(<MockLineChart data={data} theme="dark" />);
      await new Promise(resolve => setTimeout(resolve, 0));
      const end = performance.now();
      
      expect(end - start).toBeLessThan(PERFORMANCE_THRESHOLDS.THEME_SWITCH);
    });

    it('should handle theme changes across multiple charts', async () => {
      const datasets = {
        sales: generateChartData(30),
        traffic: generateChartData(40),
        conversion: generateChartData(20)
      };
      
      const { rerender } = render(
        <MockAnalyticsDashboard datasets={datasets} theme="light" />
      );
      
      const start = performance.now();
      rerender(<MockAnalyticsDashboard datasets={datasets} theme="dark" />);
      await new Promise(resolve => setTimeout(resolve, 0));
      const end = performance.now();
      
      expect(end - start).toBeLessThan(PERFORMANCE_THRESHOLDS.THEME_SWITCH * 3);
    });
  });

  describe('Responsive Chart Performance', () => {
    it('should adapt chart size efficiently', async () => {
      const data = generateChartData(50);
      const { rerender } = render(
        <MockLineChart data={data} width={400} height={300} />
      );
      
      const start = performance.now();
      rerender(<MockLineChart data={data} width={800} height={600} />);
      await new Promise(resolve => setTimeout(resolve, 0));
      const end = performance.now();
      
      expect(end - start).toBeLessThan(PERFORMANCE_THRESHOLDS.RESPONSIVE_UPDATE);
    });

    it('should handle viewport changes efficiently', async () => {
      const data = generateChartData(50);
      render(<MockLineChart data={data} responsive={true} />);
      
      const start = performance.now();
      
      // Simulate viewport change
      Object.defineProperty(window, 'innerWidth', { value: 768 });
      fireEvent(window, new Event('resize'));
      
      await new Promise(resolve => setTimeout(resolve, 50));
      const end = performance.now();
      
      expect(end - start).toBeLessThan(PERFORMANCE_THRESHOLDS.RESPONSIVE_UPDATE);
    });
  });

  describe('Dashboard Performance', () => {
    it('should render complete dashboard within threshold', async () => {
      const datasets = {
        sales: generateChartData(50),
        traffic: generateChartData(100),
        conversion: generateChartData(30),
        revenue: generateChartData(60)
      };
      
      const chartTypes = {
        sales: 'line',
        traffic: 'bar',
        conversion: 'pie',
        revenue: 'line'
      };
      
      const renderTime = await measureRenderTime(() => {
        render(
          <MockAnalyticsDashboard 
            datasets={datasets} 
            chartTypes={chartTypes}
            animated={false}
          />
        );
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.DASHBOARD_RENDER);
    });

    it('should handle chart detail view efficiently', async () => {
      const datasets = {
        sales: generateChartData(100)
      };
      
      render(<MockAnalyticsDashboard datasets={datasets} animated={false} />);
      
      const chartContainer = screen.getByTestId('chart-container-sales');
      
      const start = performance.now();
      fireEvent.click(chartContainer);
      
      await waitFor(() => {
        expect(screen.getByTestId('chart-detail')).toBeInTheDocument();
      });
      
      const end = performance.now();
      expect(end - start).toBeLessThan(PERFORMANCE_THRESHOLDS.CHART_INTERACTION);
    });

    it('should lazy load charts when not visible', async () => {
      const datasets = {
        chart1: generateChartData(50),
        chart2: generateChartData(50),
        chart3: generateChartData(50),
        chart4: generateChartData(50),
        chart5: generateChartData(50)
      };
      
      const initialMemory = measureMemoryUsage();
      
      render(<MockAnalyticsDashboard datasets={datasets} animated={false} />);
      
      const finalMemory = measureMemoryUsage();
      const memoryUsed = finalMemory - initialMemory;
      
      // Should not load all charts immediately if using lazy loading
      expect(memoryUsed).toBeLessThan(PERFORMANCE_THRESHOLDS.MEMORY_LEAK_THRESHOLD);
    });
  });

  describe('Real-time Data Updates', () => {
    it('should handle real-time data updates efficiently', async () => {
      const initialData = generateChartData(50);
      const { rerender } = render(<MockLineChart data={initialData} />);
      
      // Simulate real-time update
      const updatedData = [...initialData];
      updatedData[0] = { ...updatedData[0], value: updatedData[0].value + 100 };
      
      const start = performance.now();
      rerender(<MockLineChart data={updatedData} />);
      await new Promise(resolve => setTimeout(resolve, 0));
      const end = performance.now();
      
      expect(end - start).toBeLessThan(PERFORMANCE_THRESHOLDS.REAL_TIME_UPDATE);
    });

    it('should handle streaming data without memory leaks', async () => {
      let data = generateChartData(20);
      const { rerender } = render(<MockLineChart data={data} />);
      
      const initialMemory = measureMemoryUsage();
      
      // Simulate 50 data updates
      for (let i = 0; i < 50; i++) {
        data = [...data.slice(1), generateChartData(1)[0]];
        rerender(<MockLineChart data={data} />);
        await new Promise(resolve => setTimeout(resolve, 10));
      }
      
      if (global.gc) {
        global.gc();
      }
      
      const finalMemory = measureMemoryUsage();
      const memoryDiff = finalMemory - initialMemory;
      
      expect(memoryDiff).toBeLessThan(PERFORMANCE_THRESHOLDS.MEMORY_LEAK_THRESHOLD);
    });

    it('should batch multiple data updates efficiently', async () => {
      const data = generateChartData(100);
      const { rerender } = render(<MockLineChart data={data} />);
      
      const start = performance.now();
      
      // Multiple rapid updates
      for (let i = 0; i < 10; i++) {
        const newData = data.map(point => ({
          ...point,
          value: point.value + Math.random() * 10
        }));
        rerender(<MockLineChart data={newData} />);
      }
      
      await new Promise(resolve => setTimeout(resolve, 0));
      const end = performance.now();
      
      const avgUpdateTime = (end - start) / 10;
      expect(avgUpdateTime).toBeLessThan(PERFORMANCE_THRESHOLDS.REAL_TIME_UPDATE);
    });
  });

  describe('Memory Management', () => {
    it('should clean up chart resources properly', async () => {
      const data = generateChartData(100);
      const initialMemory = measureMemoryUsage();
      
      const { unmount } = render(<MockLineChart data={data} />);
      
      // Simulate interactions
      const dataPoint = screen.getByTestId('data-point-0');
      fireEvent.click(dataPoint);
      fireEvent.mouseEnter(dataPoint);
      fireEvent.mouseLeave(dataPoint);
      
      unmount();
      
      if (global.gc) {
        global.gc();
      }
      
      await new Promise(resolve => setTimeout(resolve, 100));
      
      const finalMemory = measureMemoryUsage();
      const memoryDiff = finalMemory - initialMemory;
      
      expect(memoryDiff).toBeLessThan(PERFORMANCE_THRESHOLDS.MEMORY_LEAK_THRESHOLD / 4);
    });

    it('should handle multiple chart instances efficiently', async () => {
      const datasets = Array.from({ length: 10 }, () => generateChartData(50));
      const initialMemory = measureMemoryUsage();
      
      const { unmount } = render(
        <div>
          {datasets.map((data, i) => (
            <MockLineChart key={i} data={data} animated={false} />
          ))}
        </div>
      );
      
      unmount();
      
      if (global.gc) {
        global.gc();
      }
      
      const finalMemory = measureMemoryUsage();
      const memoryDiff = finalMemory - initialMemory;
      
      expect(memoryDiff).toBeLessThan(PERFORMANCE_THRESHOLDS.MEMORY_LEAK_THRESHOLD);
    });
  });
});