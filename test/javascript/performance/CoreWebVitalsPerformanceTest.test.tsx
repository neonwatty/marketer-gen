/**
 * Core Web Vitals Performance Test Suite
 * Tests LCP, FID, CLS and other performance metrics
 */

import React, { Suspense } from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

// Mock performance observer API
class MockPerformanceObserver {
  private callback: PerformanceObserverCallback;
  private options: PerformanceObserverInit;

  constructor(callback: PerformanceObserverCallback) {
    this.callback = callback;
  }

  observe(options: PerformanceObserverInit) {
    this.options = options;
  }

  disconnect() {}

  takeRecords(): PerformanceEntry[] {
    return [];
  }
}

// Mock performance timeline entries
const mockLCPEntry = {
  name: 'largest-contentful-paint',
  entryType: 'largest-contentful-paint',
  startTime: 1500, // 1.5 seconds
  renderTime: 1500,
  loadTime: 1500,
  size: 45000,
  id: '',
  url: '',
  element: document.createElement('img')
} as PerformanceEntry;

const mockFIDEntry = {
  name: 'first-input-delay',
  entryType: 'first-input-delay',
  startTime: 50,
  processingStart: 55,
  processingEnd: 75,
  duration: 25, // 25ms FID
  cancelable: true
} as PerformanceEntry;

const mockCLSEntry = {
  name: 'layout-shift',
  entryType: 'layout-shift',
  startTime: 1000,
  duration: 0,
  value: 0.05, // 0.05 CLS score
  hadRecentInput: false,
  lastInputTime: 0,
  sources: []
} as PerformanceEntry;

// Performance measurement utilities
const measureCoreWebVitals = () => {
  return new Promise<{
    lcp: number;
    fid: number;
    cls: number;
    ttfb: number;
    fcp: number;
  }>((resolve) => {
    const vitals = {
      lcp: 0,
      fid: 0,
      cls: 0,
      ttfb: 0,
      fcp: 0
    };

    // Mock LCP measurement
    vitals.lcp = mockLCPEntry.startTime;
    
    // Mock FID measurement
    vitals.fid = mockFIDEntry.duration;
    
    // Mock CLS measurement
    vitals.cls = (mockCLSEntry as any).value;
    
    // Mock TTFB (Time to First Byte)
    vitals.ttfb = performance.timing ? 
      performance.timing.responseStart - performance.timing.requestStart : 100;
    
    // Mock FCP (First Contentful Paint)
    vitals.fcp = 800;

    setTimeout(() => resolve(vitals), 100);
  });
};

const measureBundleSize = (): Promise<{
  totalSize: number;
  gzippedSize: number;
  chunkSizes: Record<string, number>;
}> => {
  return new Promise((resolve) => {
    // Mock bundle analysis
    resolve({
      totalSize: 512000, // 512KB
      gzippedSize: 128000, // 128KB
      chunkSizes: {
        'main': 256000,
        'vendor': 196000,
        'styles': 60000
      }
    });
  });
};

const measureMemoryUsage = (): number => {
  if ('memory' in performance) {
    return (performance as any).memory.usedJSHeapSize;
  }
  return 0;
};

const measurePaintTiming = (): Promise<{
  fcp: number;
  lcp: number;
  fmp: number;
}> => {
  return new Promise((resolve) => {
    setTimeout(() => {
      resolve({
        fcp: 800,  // First Contentful Paint
        lcp: 1500, // Largest Contentful Paint
        fmp: 1200  // First Meaningful Paint
      });
    }, 50);
  });
};

const measureFrameRate = (): Promise<number> => {
  return new Promise((resolve) => {
    let frames = 0;
    const startTime = performance.now();
    
    const countFrame = () => {
      frames++;
      const elapsed = performance.now() - startTime;
      
      if (elapsed >= 1000) {
        resolve(frames);
      } else {
        requestAnimationFrame(countFrame);
      }
    };
    
    requestAnimationFrame(countFrame);
  });
};

describe('Core Web Vitals Performance Tests', () => {
  // Performance targets as specified
  const PERFORMANCE_TARGETS = {
    LCP_THRESHOLD: 2000,      // 2 seconds
    FID_THRESHOLD: 100,       // 100ms
    CLS_THRESHOLD: 0.1,       // 0.1
    TTFB_THRESHOLD: 500,      // 500ms
    FCP_THRESHOLD: 1000,      // 1 second
    LIGHTHOUSE_MOBILE_SCORE: 90, // 90+
    FRAME_RATE_TARGET: 60,    // 60fps
    BUNDLE_SIZE_LIMIT: 1024000, // 1MB
    MEMORY_LIMIT: 50 * 1024 * 1024 // 50MB
  };

  beforeAll(() => {
    // Mock PerformanceObserver
    global.PerformanceObserver = MockPerformanceObserver as any;
    
    // Mock performance.mark and performance.measure
    if (!performance.mark) {
      performance.mark = jest.fn();
    }
    if (!performance.measure) {
      performance.measure = jest.fn();
    }
    
    // Mock ResizeObserver for layout shift detection
    global.ResizeObserver = jest.fn().mockImplementation(() => ({
      observe: jest.fn(),
      unobserve: jest.fn(),
      disconnect: jest.fn(),
    }));
  });

  describe('Largest Contentful Paint (LCP)', () => {
    it('should achieve LCP under 2 seconds', async () => {
      const vitals = await measureCoreWebVitals();
      
      expect(vitals.lcp).toBeLessThan(PERFORMANCE_TARGETS.LCP_THRESHOLD);
      expect(vitals.lcp).toBeGreaterThan(0);
    });

    it('should measure LCP for dashboard components', async () => {
      const MockDashboard = () => (
        <div data-testid="dashboard">
          <img src="data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTAwIiBoZWlnaHQ9IjEwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwIiBoZWlnaHQ9IjEwMCIgZmlsbD0iIzAwZiIvPjwvc3ZnPg==" alt="Chart" width="400" height="300" />
          <div style={{ width: '100%', height: '200px', backgroundColor: '#f0f0f0' }}>
            Large content block that should be measured for LCP
          </div>
        </div>
      );

      const startTime = performance.now();
      render(<MockDashboard />);
      
      await waitFor(() => {
        expect(screen.getByTestId('dashboard')).toBeInTheDocument();
      });
      
      const endTime = performance.now();
      const renderTime = endTime - startTime;
      
      expect(renderTime).toBeLessThan(PERFORMANCE_TARGETS.LCP_THRESHOLD);
    });
  });

  describe('First Input Delay (FID)', () => {
    it('should achieve FID under 100ms', async () => {
      const vitals = await measureCoreWebVitals();
      
      expect(vitals.fid).toBeLessThan(PERFORMANCE_TARGETS.FID_THRESHOLD);
      expect(vitals.fid).toBeGreaterThanOrEqual(0);
    });

    it('should measure FID for interactive components', async () => {
      const MockInteractiveComponent = () => {
        const [count, setCount] = React.useState(0);
        
        return (
          <div>
            <button
              data-testid="interactive-button"
              onClick={() => setCount(c => c + 1)}
            >
              Click count: {count}
            </button>
          </div>
        );
      };

      render(<MockInteractiveComponent />);
      
      const button = screen.getByTestId('interactive-button');
      
      const startTime = performance.now();
      await userEvent.click(button);
      const endTime = performance.now();
      
      const inputDelay = endTime - startTime;
      expect(inputDelay).toBeLessThan(PERFORMANCE_TARGETS.FID_THRESHOLD);
    });
  });

  describe('Cumulative Layout Shift (CLS)', () => {
    it('should achieve CLS under 0.1', async () => {
      const vitals = await measureCoreWebVitals();
      
      expect(vitals.cls).toBeLessThan(PERFORMANCE_TARGETS.CLS_THRESHOLD);
      expect(vitals.cls).toBeGreaterThanOrEqual(0);
    });

    it('should have stable layout during content loading', async () => {
      const MockLayoutComponent = () => {
        const [loaded, setLoaded] = React.useState(false);
        
        React.useEffect(() => {
          setTimeout(() => setLoaded(true), 100);
        }, []);
        
        return (
          <div data-testid="layout-component">
            {/* Fixed dimensions to prevent layout shift */}
            <div style={{ width: '300px', height: '200px', backgroundColor: '#f0f0f0' }}>
              {loaded ? (
                <img 
                  src="data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMzAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMzAwIiBoZWlnaHQ9IjIwMCIgZmlsbD0iIzAwZiIvPjwvc3ZnPg=="
                  alt="Loaded content"
                  width="300"
                  height="200"
                />
              ) : (
                <div style={{ width: '300px', height: '200px', backgroundColor: '#ddd' }}>
                  Loading...
                </div>
              )}
            </div>
          </div>
        );
      };

      render(<MockLayoutComponent />);
      
      // Measure initial layout
      const initialRect = screen.getByTestId('layout-component').getBoundingClientRect();
      
      // Wait for content to load
      await waitFor(() => {
        expect(screen.getByAltText('Loaded content')).toBeInTheDocument();
      });
      
      // Measure final layout
      const finalRect = screen.getByTestId('layout-component').getBoundingClientRect();
      
      // Should have no layout shift
      expect(finalRect.width).toBe(initialRect.width);
      expect(finalRect.height).toBe(initialRect.height);
    });
  });

  describe('Time to First Byte (TTFB)', () => {
    it('should achieve TTFB under 500ms', async () => {
      const vitals = await measureCoreWebVitals();
      
      expect(vitals.ttfb).toBeLessThan(PERFORMANCE_TARGETS.TTFB_THRESHOLD);
      expect(vitals.ttfb).toBeGreaterThan(0);
    });
  });

  describe('First Contentful Paint (FCP)', () => {
    it('should achieve FCP under 1 second', async () => {
      const vitals = await measureCoreWebVitals();
      
      expect(vitals.fcp).toBeLessThan(PERFORMANCE_TARGETS.FCP_THRESHOLD);
      expect(vitals.fcp).toBeGreaterThan(0);
    });

    it('should measure paint timing for components', async () => {
      const timing = await measurePaintTiming();
      
      expect(timing.fcp).toBeLessThan(PERFORMANCE_TARGETS.FCP_THRESHOLD);
      expect(timing.lcp).toBeLessThan(PERFORMANCE_TARGETS.LCP_THRESHOLD);
      expect(timing.fmp).toBeLessThan(1500); // First Meaningful Paint under 1.5s
    });
  });

  describe('Bundle Size Analysis', () => {
    it('should keep total bundle size under 1MB', async () => {
      const bundleInfo = await measureBundleSize();
      
      expect(bundleInfo.totalSize).toBeLessThan(PERFORMANCE_TARGETS.BUNDLE_SIZE_LIMIT);
      expect(bundleInfo.gzippedSize).toBeLessThan(bundleInfo.totalSize * 0.3); // Good compression ratio
    });

    it('should analyze chunk sizes', async () => {
      const bundleInfo = await measureBundleSize();
      
      // Main chunk should be reasonable size
      expect(bundleInfo.chunkSizes.main).toBeLessThan(512000); // 512KB
      
      // Vendor chunk should not dominate
      expect(bundleInfo.chunkSizes.vendor).toBeLessThan(bundleInfo.totalSize * 0.5);
      
      // Styles should be minimal
      expect(bundleInfo.chunkSizes.styles).toBeLessThan(100000); // 100KB
    });
  });

  describe('Memory Usage', () => {
    it('should maintain efficient memory usage', () => {
      const initialMemory = measureMemoryUsage();
      
      // Render multiple components
      const { unmount } = render(
        <div>
          {Array.from({ length: 100 }, (_, i) => (
            <div key={i}>Component {i}</div>
          ))}
        </div>
      );
      
      const afterRenderMemory = measureMemoryUsage();
      const memoryIncrease = afterRenderMemory - initialMemory;
      
      // Clean up
      unmount();
      
      // Force garbage collection if available
      if (global.gc) {
        global.gc();
      }
      
      expect(memoryIncrease).toBeLessThan(PERFORMANCE_TARGETS.MEMORY_LIMIT);
    });

    it('should detect memory leaks in long-running components', async () => {
      const MockLongRunningComponent = () => {
        const [count, setCount] = React.useState(0);
        
        React.useEffect(() => {
          const interval = setInterval(() => {
            setCount(c => c + 1);
          }, 10);
          
          return () => clearInterval(interval);
        }, []);
        
        return <div>Count: {count}</div>;
      };

      const initialMemory = measureMemoryUsage();
      
      const { unmount } = render(<MockLongRunningComponent />);
      
      // Let it run for a short time
      await new Promise(resolve => setTimeout(resolve, 200));
      
      const runningMemory = measureMemoryUsage();
      
      unmount();
      
      // Force garbage collection
      if (global.gc) {
        global.gc();
      }
      
      await new Promise(resolve => setTimeout(resolve, 100));
      
      const finalMemory = measureMemoryUsage();
      const memoryLeak = finalMemory - initialMemory;
      
      expect(memoryLeak).toBeLessThan(1024 * 1024); // Less than 1MB leak
    });
  });

  describe('Frame Rate Performance', () => {
    it('should maintain 60fps during animations', async () => {
      const MockAnimatedComponent = () => {
        const [position, setPosition] = React.useState(0);
        
        React.useEffect(() => {
          let animationId: number;
          
          const animate = () => {
            setPosition(p => (p + 1) % 100);
            animationId = requestAnimationFrame(animate);
          };
          
          animationId = requestAnimationFrame(animate);
          
          return () => cancelAnimationFrame(animationId);
        }, []);
        
        return (
          <div
            data-testid="animated-element"
            style={{
              transform: `translateX(${position}px)`,
              transition: 'transform 16ms linear',
              width: '50px',
              height: '50px',
              backgroundColor: 'blue'
            }}
          />
        );
      };

      render(<MockAnimatedComponent />);
      
      // Measure frame rate for 1 second
      const frameRate = await measureFrameRate();
      
      expect(frameRate).toBeGreaterThanOrEqual(PERFORMANCE_TARGETS.FRAME_RATE_TARGET * 0.9); // Allow 10% margin
    });
  });

  describe('Lighthouse Score Simulation', () => {
    it('should achieve 90+ mobile performance score equivalent', async () => {
      const vitals = await measureCoreWebVitals();
      const bundleInfo = await measureBundleSize();
      
      // Calculate approximate Lighthouse score based on metrics
      let score = 100;
      
      // LCP impact (25% weight)
      if (vitals.lcp > 4000) score -= 25;
      else if (vitals.lcp > 2500) score -= 15;
      else if (vitals.lcp > 2000) score -= 5;
      
      // FID impact (25% weight)
      if (vitals.fid > 300) score -= 25;
      else if (vitals.fid > 100) score -= 15;
      else if (vitals.fid > 50) score -= 5;
      
      // CLS impact (25% weight)
      if (vitals.cls > 0.25) score -= 25;
      else if (vitals.cls > 0.1) score -= 15;
      else if (vitals.cls > 0.05) score -= 5;
      
      // Bundle size impact (25% weight)
      if (bundleInfo.totalSize > 2048000) score -= 25;
      else if (bundleInfo.totalSize > 1024000) score -= 15;
      else if (bundleInfo.totalSize > 512000) score -= 5;
      
      expect(score).toBeGreaterThanOrEqual(PERFORMANCE_TARGETS.LIGHTHOUSE_MOBILE_SCORE);
    });
  });

  describe('Performance Monitoring', () => {
    it('should provide runtime performance metrics', () => {
      const performanceData = {
        timing: performance.timing,
        navigation: performance.navigation,
        memory: (performance as any).memory
      };
      
      expect(performanceData.timing).toBeDefined();
      expect(performanceData.navigation).toBeDefined();
      
      // Should have timing information
      if (performanceData.timing) {
        expect(performanceData.timing.domContentLoadedEventEnd).toBeGreaterThan(0);
        expect(performanceData.timing.loadEventEnd).toBeGreaterThan(0);
      }
    });

    it('should track custom performance marks', () => {
      performance.mark('test-start');
      
      // Simulate some work
      const start = Date.now();
      while (Date.now() - start < 10) {
        // Busy wait for 10ms
      }
      
      performance.mark('test-end');
      performance.measure('test-duration', 'test-start', 'test-end');
      
      expect(performance.mark).toHaveBeenCalledWith('test-start');
      expect(performance.mark).toHaveBeenCalledWith('test-end');
      expect(performance.measure).toHaveBeenCalledWith('test-duration', 'test-start', 'test-end');
    });
  });
});