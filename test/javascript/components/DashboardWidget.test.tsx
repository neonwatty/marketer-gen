import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { axe, toHaveNoViolations } from 'jest-axe';

expect.extend(toHaveNoViolations);

// Mock component that doesn't exist yet - this will fail initially (TDD)
const DashboardWidget = ({ title, children, collapsible = false, loading = false, error = null, ...props }: any) => {
  throw new Error('DashboardWidget component not implemented yet');
};

describe('DashboardWidget', () => {
  describe('Basic Rendering', () => {
    it('should render widget with title', () => {
      render(<DashboardWidget title="Campaign Overview" />);
      expect(screen.getByText('Campaign Overview')).toBeInTheDocument();
    });

    it('should render widget content', () => {
      render(
        <DashboardWidget title="Test Widget">
          <div>Widget Content</div>
        </DashboardWidget>
      );
      expect(screen.getByText('Widget Content')).toBeInTheDocument();
    });

    it('should apply custom className', () => {
      render(
        <DashboardWidget 
          title="Test Widget" 
          className="custom-class"
          data-testid="widget"
        />
      );
      expect(screen.getByTestId('widget')).toHaveClass('custom-class');
    });
  });

  describe('Loading States', () => {
    it('should show loading spinner when loading', () => {
      render(<DashboardWidget title="Loading Widget" loading={true} />);
      expect(screen.getByRole('status')).toBeInTheDocument();
      expect(screen.getByText(/loading/i)).toBeInTheDocument();
    });

    it('should not show content when loading', () => {
      render(
        <DashboardWidget title="Loading Widget" loading={true}>
          <div>Hidden Content</div>
        </DashboardWidget>
      );
      expect(screen.queryByText('Hidden Content')).not.toBeInTheDocument();
    });

    it('should show skeleton loader for performance', () => {
      render(<DashboardWidget title="Skeleton Widget" loading={true} />);
      expect(screen.getByTestId('skeleton-loader')).toBeInTheDocument();
    });
  });

  describe('Error Handling', () => {
    it('should display error message when error occurs', () => {
      const error = 'Failed to load widget data';
      render(<DashboardWidget title="Error Widget" error={error} />);
      expect(screen.getByText(error)).toBeInTheDocument();
    });

    it('should show retry button on error', async () => {
      const mockRetry = jest.fn();
      render(
        <DashboardWidget 
          title="Error Widget" 
          error="Network error"
          onRetry={mockRetry}
        />
      );
      
      const retryButton = screen.getByRole('button', { name: /retry/i });
      await userEvent.click(retryButton);
      expect(mockRetry).toHaveBeenCalledTimes(1);
    });

    it('should have proper error styling', () => {
      render(
        <DashboardWidget 
          title="Error Widget" 
          error="Error message"
          data-testid="error-widget"
        />
      );
      expect(screen.getByTestId('error-widget')).toHaveClass('widget-error');
    });
  });

  describe('Collapsible Functionality', () => {
    it('should be collapsible when collapsible prop is true', async () => {
      render(
        <DashboardWidget title="Collapsible Widget" collapsible={true}>
          <div>Collapsible Content</div>
        </DashboardWidget>
      );
      
      const toggleButton = screen.getByRole('button', { name: /collapse|expand/i });
      expect(toggleButton).toBeInTheDocument();
    });

    it('should toggle content visibility when collapsed', async () => {
      render(
        <DashboardWidget title="Collapsible Widget" collapsible={true}>
          <div>Toggle Content</div>
        </DashboardWidget>
      );
      
      const toggleButton = screen.getByRole('button', { name: /collapse/i });
      await userEvent.click(toggleButton);
      
      expect(screen.queryByText('Toggle Content')).not.toBeVisible();
    });

    it('should save collapse state in localStorage', async () => {
      const mockSetItem = jest.spyOn(Storage.prototype, 'setItem');
      
      render(
        <DashboardWidget 
          title="Persistent Widget" 
          collapsible={true}
          widgetId="persistent-widget"
        />
      );
      
      const toggleButton = screen.getByRole('button', { name: /collapse/i });
      await userEvent.click(toggleButton);
      
      expect(mockSetItem).toHaveBeenCalledWith(
        'widget-persistent-widget-collapsed',
        'true'
      );
    });
  });

  describe('Performance Tests', () => {
    it('should render within 100ms', async () => {
      const renderTime = await global.testUtils.measureRenderTime(() => {
        render(<DashboardWidget title="Performance Widget" />);
      });
      
      expect(renderTime).toBeLessThan(100);
    });

    it('should handle large datasets efficiently', async () => {
      const largeData = Array.from({ length: 1000 }, (_, i) => ({
        id: i,
        name: `Item ${i}`,
        value: Math.random() * 100
      }));
      
      const renderTime = await global.testUtils.measureRenderTime(() => {
        render(
          <DashboardWidget title="Large Dataset Widget">
            {largeData.map(item => (
              <div key={item.id}>{item.name}: {item.value}</div>
            ))}
          </DashboardWidget>
        );
      });
      
      expect(renderTime).toBeLessThan(100);
    });

    it('should implement virtualization for large lists', () => {
      const largeData = Array.from({ length: 10000 }, (_, i) => i);
      
      render(
        <DashboardWidget title="Virtualized Widget" virtualized={true}>
          {largeData}
        </DashboardWidget>
      );
      
      // Should only render visible items
      expect(screen.getAllByTestId(/^virtualized-item-/)).toHaveLength(10);
    });
  });

  describe('Accessibility', () => {
    it('should have no accessibility violations', async () => {
      const { container } = render(
        <DashboardWidget title="Accessible Widget">
          <div>Accessible Content</div>
        </DashboardWidget>
      );
      
      const results = await axe(container, global.axeConfig);
      expect(results).toHaveNoViolations();
    });

    it('should have proper ARIA labels', () => {
      render(
        <DashboardWidget 
          title="ARIA Widget"
          ariaLabel="Campaign metrics widget"
        />
      );
      
      expect(screen.getByLabelText('Campaign metrics widget')).toBeInTheDocument();
    });

    it('should support keyboard navigation', async () => {
      render(
        <DashboardWidget title="Keyboard Widget" collapsible={true}>
          <button>Interactive Element</button>
        </DashboardWidget>
      );
      
      const toggleButton = screen.getByRole('button', { name: /collapse/i });
      
      // Tab to toggle button
      await userEvent.tab();
      expect(toggleButton).toHaveFocus();
      
      // Press Enter to toggle
      await userEvent.keyboard('{Enter}');
      await waitFor(() => {
        expect(screen.queryByRole('button', { name: 'Interactive Element' }))
          .not.toBeVisible();
      });
    });

    it('should announce state changes to screen readers', async () => {
      render(
        <DashboardWidget title="Screen Reader Widget" collapsible={true}>
          <div>Content for screen readers</div>
        </DashboardWidget>
      );
      
      const toggleButton = screen.getByRole('button', { name: /collapse/i });
      await userEvent.click(toggleButton);
      
      expect(screen.getByText('Widget collapsed')).toHaveAttribute('aria-live', 'polite');
    });
  });

  describe('Responsive Design', () => {
    const breakpoints = [
      { name: 'mobile', width: 320 },
      { name: 'tablet', width: 768 },
      { name: 'desktop', width: 1024 },
      { name: 'wide', width: 1440 },
      { name: 'ultrawide', width: 2560 }
    ];

    breakpoints.forEach(({ name, width }) => {
      it(`should render correctly at ${name} breakpoint (${width}px)`, () => {
        global.testUtils.mockViewport(width, 800);
        
        render(
          <DashboardWidget 
            title={`${name} Widget`}
            data-testid={`widget-${name}`}
          >
            <div>Responsive Content</div>
          </DashboardWidget>
        );
        
        const widget = screen.getByTestId(`widget-${name}`);
        expect(widget).toHaveClass(`widget-${name}`);
        expect(widget).toBeInTheDocument();
      });
    });

    it('should adapt layout for mobile devices', () => {
      global.testUtils.mockViewport(320, 568);
      
      render(
        <DashboardWidget 
          title="Mobile Widget"
          data-testid="mobile-widget"
        >
          <div>Mobile Content</div>
        </DashboardWidget>
      );
      
      const widget = screen.getByTestId('mobile-widget');
      expect(widget).toHaveClass('widget-mobile');
      expect(widget).toHaveClass('widget-stacked');
    });

    it('should handle touch interactions on mobile', async () => {
      global.testUtils.mockViewport(320, 568);
      const mockTouch = jest.fn();
      
      render(
        <DashboardWidget 
          title="Touch Widget"
          collapsible={true}
          onTouch={mockTouch}
        />
      );
      
      const toggleButton = screen.getByRole('button', { name: /collapse/i });
      
      // Simulate touch event
      fireEvent.touchStart(toggleButton);
      fireEvent.touchEnd(toggleButton);
      
      expect(mockTouch).toHaveBeenCalled();
    });
  });

  describe('Theme Integration', () => {
    it('should apply theme classes', () => {
      render(
        <DashboardWidget 
          title="Themed Widget"
          theme="dark"
          data-testid="themed-widget"
        />
      );
      
      expect(screen.getByTestId('themed-widget')).toHaveClass('theme-dark');
    });

    it('should support custom brand colors', () => {
      const brandColors = {
        primary: '#007bff',
        secondary: '#6c757d',
        success: '#28a745'
      };
      
      render(
        <DashboardWidget 
          title="Brand Widget"
          brandColors={brandColors}
          data-testid="brand-widget"
        />
      );
      
      const widget = screen.getByTestId('brand-widget');
      expect(widget).toHaveStyle(`--primary-color: ${brandColors.primary}`);
    });

    it('should adapt to high contrast mode', () => {
      // Mock high contrast media query
      Object.defineProperty(window, 'matchMedia', {
        writable: true,
        value: jest.fn().mockImplementation(query => ({
          matches: query === '(prefers-contrast: high)',
          media: query,
          onchange: null,
          addListener: jest.fn(),
          removeListener: jest.fn(),
          addEventListener: jest.fn(),
          removeEventListener: jest.fn(),
          dispatchEvent: jest.fn(),
        })),
      });
      
      render(
        <DashboardWidget 
          title="High Contrast Widget"
          data-testid="contrast-widget"
        />
      );
      
      expect(screen.getByTestId('contrast-widget')).toHaveClass('high-contrast');
    });
  });

  describe('Data Integration', () => {
    it('should display real-time data updates', async () => {
      const mockData = { value: 100, trend: 'up' };
      
      render(
        <DashboardWidget 
          title="Real-time Widget"
          data={mockData}
          realTime={true}
        />
      );
      
      expect(screen.getByText('100')).toBeInTheDocument();
      expect(screen.getByTestId('trend-indicator')).toHaveClass('trend-up');
    });

    it('should handle data updates via WebSocket', async () => {
      const mockWebSocket = {
        addEventListener: jest.fn(),
        removeEventListener: jest.fn(),
        send: jest.fn(),
        close: jest.fn()
      };
      
      global.WebSocket = jest.fn(() => mockWebSocket);
      
      render(
        <DashboardWidget 
          title="WebSocket Widget"
          websocketUrl="ws://localhost:3000/dashboard"
          data-testid="websocket-widget"
        />
      );
      
      expect(global.WebSocket).toHaveBeenCalledWith('ws://localhost:3000/dashboard');
      expect(mockWebSocket.addEventListener).toHaveBeenCalledWith('message', expect.any(Function));
    });
  });
});

// Export for use in integration tests
export { DashboardWidget };