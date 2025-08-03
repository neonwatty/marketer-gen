import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import { AdvancedLineChart, DonutChart, DEFAULT_THEME } from '../../../app/javascript/components/AdvancedCharts';

// Mock recharts components
jest.mock('recharts', () => ({
  ResponsiveContainer: ({ children }) => <div data-testid="responsive-container">{children}</div>,
  LineChart: ({ children }) => <div data-testid="line-chart">{children}</div>,
  Line: () => <div data-testid="line" />,
  PieChart: ({ children }) => <div data-testid="pie-chart">{children}</div>,
  Pie: ({ children }) => <div data-testid="pie">{children}</div>,
  Cell: () => <div data-testid="cell" />,
  XAxis: () => <div data-testid="x-axis" />,
  YAxis: () => <div data-testid="y-axis" />,
  CartesianGrid: () => <div data-testid="cartesian-grid" />,
  Tooltip: () => <div data-testid="tooltip" />,
  Legend: () => <div data-testid="legend" />
}));

// Mock visx components
jest.mock('@visx/zoom', () => ({
  Zoom: ({ children }) => children({ scale: 1, translateX: 0, translateY: 0 })
}));

const mockData = [
  { name: 'Jan', value: 100, date: '2025-01-01' },
  { name: 'Feb', value: 150, date: '2025-02-01' },
  { name: 'Mar', value: 200, date: '2025-03-01' }
];

describe('AdvancedCharts', () => {
  describe('AdvancedLineChart', () => {
    it('renders without crashing', () => {
      render(
        <AdvancedLineChart 
          data={mockData} 
          options={{ theme: DEFAULT_THEME }} 
        />
      );
      
      expect(screen.getByTestId('responsive-container')).toBeInTheDocument();
      expect(screen.getByTestId('line-chart')).toBeInTheDocument();
    });

    it('shows zoom controls when enabled', () => {
      render(
        <AdvancedLineChart 
          data={mockData} 
          options={{ showZoom: true, theme: DEFAULT_THEME }} 
        />
      );
      
      // Check if zoom level indicator is present
      expect(screen.getByText(/Zoom: \d+%/)).toBeInTheDocument();
    });

    it('handles data point clicks', () => {
      const mockOnClick = jest.fn();
      
      render(
        <AdvancedLineChart 
          data={mockData} 
          options={{ theme: DEFAULT_THEME }}
          onDataPointClick={mockOnClick}
        />
      );
      
      expect(screen.getByTestId('line-chart')).toBeInTheDocument();
    });
  });

  describe('DonutChart', () => {
    it('renders with center text', () => {
      render(
        <DonutChart 
          data={mockData} 
          options={{ theme: DEFAULT_THEME }}
          centerText="Total: 450"
        />
      );
      
      expect(screen.getByTestId('responsive-container')).toBeInTheDocument();
      expect(screen.getByTestId('pie-chart')).toBeInTheDocument();
      expect(screen.getByText('Total: 450')).toBeInTheDocument();
    });

    it('applies theme colors correctly', () => {
      const customTheme = {
        ...DEFAULT_THEME,
        colors: ['#FF0000', '#00FF00', '#0000FF']
      };

      render(
        <DonutChart 
          data={mockData} 
          options={{ theme: customTheme }}
        />
      );
      
      expect(screen.getByTestId('pie-chart')).toBeInTheDocument();
    });
  });

  describe('DEFAULT_THEME', () => {
    it('has required properties', () => {
      expect(DEFAULT_THEME).toHaveProperty('primary');
      expect(DEFAULT_THEME).toHaveProperty('secondary');
      expect(DEFAULT_THEME).toHaveProperty('accent');
      expect(DEFAULT_THEME).toHaveProperty('background');
      expect(DEFAULT_THEME).toHaveProperty('text');
      expect(DEFAULT_THEME).toHaveProperty('grid');
      expect(DEFAULT_THEME).toHaveProperty('colors');
      expect(Array.isArray(DEFAULT_THEME.colors)).toBe(true);
    });

    it('has proper color values', () => {
      expect(DEFAULT_THEME.primary).toBe('#0088FE');
      expect(DEFAULT_THEME.secondary).toBe('#00C49F');
      expect(DEFAULT_THEME.background).toBe('#FFFFFF');
      expect(DEFAULT_THEME.colors.length).toBeGreaterThan(0);
    });
  });
});