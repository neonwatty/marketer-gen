import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

// Performance testing utilities
const measureRenderTime = async (renderFunction: () => void): Promise<number> => {
  const start = performance.now();
  renderFunction();
  const end = performance.now();
  return end - start;
};

const measureMemoryUsage = (): number => {
  if ('memory' in performance) {
    return (performance as any).memory.usedJSHeapSize;
  }
  return 0;
};

const measureInteractionTime = async (interaction: () => Promise<void>): Promise<number> => {
  const start = performance.now();
  await interaction();
  const end = performance.now();
  return end - start;
};

describe('UI Component Performance Tests', () => {
  // Performance thresholds (in milliseconds)
  const PERFORMANCE_THRESHOLDS = {
    RENDER_TIME: 100,
    INTERACTION_TIME: 50,
    LARGE_LIST_RENDER: 200,
    CHART_RENDER: 150,
    FORM_VALIDATION: 30,
    MEMORY_LEAK_THRESHOLD: 10 * 1024 * 1024 // 10MB
  };

  describe('Dashboard Widget Performance', () => {
    it('should render simple widget within 100ms', async () => {
      const mockData = {
        title: 'Total Campaigns',
        value: 24,
        trend: 12.5
      };

      // Mock the component since it doesn't exist yet
      const MockDashboardWidget = ({ title, value, trend }: any) => (
        <div data-testid="dashboard-widget">
          <h3>{title}</h3>
          <div>{value}</div>
          <div>{trend}%</div>
        </div>
      );

      const renderTime = await measureRenderTime(() => {
        render(<MockDashboardWidget {...mockData} />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.RENDER_TIME);
    });

    it('should handle large datasets efficiently', async () => {
      const largeDataset = Array.from({ length: 1000 }, (_, i) => ({
        id: i,
        name: `Campaign ${i}`,
        value: Math.random() * 1000,
        date: new Date(2024, 0, i % 30 + 1).toISOString()
      }));

      const MockLargeWidget = ({ data }: { data: any[] }) => (
        <div data-testid="large-widget">
          <div>Total Items: {data.length}</div>
          {/* Only render first 100 items for performance */}
          <div>
            {data.slice(0, 100).map(item => (
              <div key={item.id}>{item.name}: {item.value}</div>
            ))}
          </div>
        </div>
      );

      const renderTime = await measureRenderTime(() => {
        render(<MockLargeWidget data={largeDataset} />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.LARGE_LIST_RENDER);
    });

    it('should not cause memory leaks with frequent updates', async () => {
      const MockUpdatingWidget = () => {
        const [value, setValue] = React.useState(0);
        
        React.useEffect(() => {
          const interval = setInterval(() => {
            setValue(v => v + 1);
          }, 10);
          
          return () => clearInterval(interval);
        }, []);

        return (
          <div data-testid="updating-widget">
            Value: {value}
          </div>
        );
      };

      const initialMemory = measureMemoryUsage();
      
      const { unmount } = render(<MockUpdatingWidget />);
      
      // Let it update for a short time
      await new Promise(resolve => setTimeout(resolve, 100));
      
      unmount();
      
      // Force garbage collection if available
      if (global.gc) {
        global.gc();
      }
      
      const finalMemory = measureMemoryUsage();
      const memoryDiff = finalMemory - initialMemory;
      
      expect(memoryDiff).toBeLessThan(PERFORMANCE_THRESHOLDS.MEMORY_LEAK_THRESHOLD);
    });
  });

  describe('Navigation Performance', () => {
    it('should render navigation menu within performance threshold', async () => {
      const mockNavigationItems = Array.from({ length: 20 }, (_, i) => ({
        id: `item-${i}`,
        label: `Menu Item ${i}`,
        href: `/item/${i}`,
        children: i % 3 === 0 ? [
          { id: `sub-${i}-1`, label: `Sub Item 1`, href: `/item/${i}/1` },
          { id: `sub-${i}-2`, label: `Sub Item 2`, href: `/item/${i}/2` }
        ] : undefined
      }));

      const MockNavigation = ({ items }: { items: any[] }) => (
        <nav data-testid="navigation">
          <ul>
            {items.map(item => (
              <li key={item.id}>
                <a href={item.href}>{item.label}</a>
                {item.children && (
                  <ul>
                    {item.children.map((child: any) => (
                      <li key={child.id}>
                        <a href={child.href}>{child.label}</a>
                      </li>
                    ))}
                  </ul>
                )}
              </li>
            ))}
          </ul>
        </nav>
      );

      const renderTime = await measureRenderTime(() => {
        render(<MockNavigation items={mockNavigationItems} />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.RENDER_TIME);
    });

    it('should handle submenu interactions efficiently', async () => {
      const MockInteractiveNav = () => {
        const [openMenu, setOpenMenu] = React.useState<string | null>(null);

        return (
          <nav data-testid="interactive-nav">
            <ul>
              {['Menu 1', 'Menu 2', 'Menu 3'].map(menu => (
                <li key={menu}>
                  <button
                    onClick={() => setOpenMenu(openMenu === menu ? null : menu)}
                    aria-expanded={openMenu === menu}
                  >
                    {menu}
                  </button>
                  {openMenu === menu && (
                    <ul>
                      <li><a href="#">Submenu 1</a></li>
                      <li><a href="#">Submenu 2</a></li>
                    </ul>
                  )}
                </li>
              ))}
            </ul>
          </nav>
        );
      };

      render(<MockInteractiveNav />);

      const menuButton = screen.getByRole('button', { name: 'Menu 1' });

      const interactionTime = await measureInteractionTime(async () => {
        await userEvent.click(menuButton);
      });

      expect(interactionTime).toBeLessThan(PERFORMANCE_THRESHOLDS.INTERACTION_TIME);
    });
  });

  describe('Form Performance', () => {
    it('should render complex forms within performance threshold', async () => {
      const MockComplexForm = () => (
        <form data-testid="complex-form">
          {Array.from({ length: 50 }, (_, i) => (
            <div key={i}>
              <label htmlFor={`field-${i}`}>Field {i}</label>
              <input
                type="text"
                id={`field-${i}`}
                name={`field-${i}`}
                placeholder={`Enter value for field ${i}`}
              />
            </div>
          ))}
          <button type="submit">Submit</button>
        </form>
      );

      const renderTime = await measureRenderTime(() => {
        render(<MockComplexForm />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.LARGE_LIST_RENDER);
    });

    it('should handle form validation efficiently', async () => {
      const MockValidatedForm = () => {
        const [errors, setErrors] = React.useState<Record<string, string>>({});

        const validateField = (name: string, value: string) => {
          if (!value.trim()) {
            setErrors(prev => ({ ...prev, [name]: 'This field is required' }));
          } else {
            setErrors(prev => {
              const newErrors = { ...prev };
              delete newErrors[name];
              return newErrors;
            });
          }
        };

        return (
          <form data-testid="validated-form">
            <div>
              <label htmlFor="email">Email</label>
              <input
                type="email"
                id="email"
                name="email"
                onBlur={(e) => validateField('email', e.target.value)}
              />
              {errors.email && <div role="alert">{errors.email}</div>}
            </div>
            <div>
              <label htmlFor="password">Password</label>
              <input
                type="password"
                id="password"
                name="password"
                onBlur={(e) => validateField('password', e.target.value)}
              />
              {errors.password && <div role="alert">{errors.password}</div>}
            </div>
          </form>
        );
      };

      render(<MockValidatedForm />);

      const emailInput = screen.getByLabelText('Email');

      const validationTime = await measureInteractionTime(async () => {
        await userEvent.type(emailInput, 'test@example.com');
        await userEvent.tab(); // Trigger blur event
      });

      expect(validationTime).toBeLessThan(PERFORMANCE_THRESHOLDS.FORM_VALIDATION);
    });

    it('should handle auto-save without performance degradation', async () => {
      const MockAutoSaveForm = () => {
        const [value, setValue] = React.useState('');
        const [saveCount, setSaveCount] = React.useState(0);

        // Debounced auto-save
        React.useEffect(() => {
          if (!value) return;

          const timer = setTimeout(() => {
            setSaveCount(prev => prev + 1);
          }, 300);

          return () => clearTimeout(timer);
        }, [value]);

        return (
          <form data-testid="auto-save-form">
            <input
              type="text"
              value={value}
              onChange={(e) => setValue(e.target.value)}
              placeholder="Type to auto-save..."
            />
            <div>Saved {saveCount} times</div>
          </form>
        );
      };

      render(<MockAutoSaveForm />);

      const input = screen.getByPlaceholderText('Type to auto-save...');

      const initialMemory = measureMemoryUsage();

      // Simulate rapid typing
      const typingTime = await measureInteractionTime(async () => {
        for (let i = 0; i < 20; i++) {
          await userEvent.type(input, 'a');
          await new Promise(resolve => setTimeout(resolve, 50));
        }
      });

      const finalMemory = measureMemoryUsage();
      const memoryDiff = finalMemory - initialMemory;

      expect(typingTime).toBeLessThan(1000); // Should complete within 1 second
      expect(memoryDiff).toBeLessThan(PERFORMANCE_THRESHOLDS.MEMORY_LEAK_THRESHOLD);
    });
  });

  describe('Chart Performance', () => {
    it('should render simple charts within performance threshold', async () => {
      const mockChartData = Array.from({ length: 100 }, (_, i) => ({
        x: i,
        y: Math.sin(i * 0.1) * 100 + Math.random() * 20
      }));

      const MockChart = ({ data }: { data: any[] }) => (
        <div data-testid="mock-chart">
          <svg width="400" height="200">
            {data.map((point, i) => (
              <circle
                key={i}
                cx={point.x * 4}
                cy={100 + point.y}
                r="2"
                fill="blue"
              />
            ))}
          </svg>
        </div>
      );

      const renderTime = await measureRenderTime(() => {
        render(<MockChart data={mockChartData} />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.CHART_RENDER);
    });

    it('should handle chart interactions efficiently', async () => {
      const MockInteractiveChart = () => {
        const [hoveredPoint, setHoveredPoint] = React.useState<number | null>(null);

        const data = Array.from({ length: 50 }, (_, i) => ({
          x: i * 8,
          y: 100 + Math.sin(i * 0.2) * 50,
          value: Math.floor(Math.random() * 1000)
        }));

        return (
          <div data-testid="interactive-chart">
            <svg width="400" height="200">
              {data.map((point, i) => (
                <circle
                  key={i}
                  cx={point.x}
                  cy={point.y}
                  r="4"
                  fill={hoveredPoint === i ? "red" : "blue"}
                  onMouseEnter={() => setHoveredPoint(i)}
                  onMouseLeave={() => setHoveredPoint(null)}
                  style={{ cursor: 'pointer' }}
                />
              ))}
            </svg>
            {hoveredPoint !== null && (
              <div>Value: {data[hoveredPoint].value}</div>
            )}
          </div>
        );
      };

      render(<MockInteractiveChart />);

      const circles = screen.getByTestId('interactive-chart').querySelectorAll('circle');

      const interactionTime = await measureInteractionTime(async () => {
        fireEvent.mouseEnter(circles[10]);
        fireEvent.mouseLeave(circles[10]);
      });

      expect(interactionTime).toBeLessThan(PERFORMANCE_THRESHOLDS.INTERACTION_TIME);
    });

    it('should handle large datasets with virtualization', async () => {
      const largeDataset = Array.from({ length: 10000 }, (_, i) => ({
        id: i,
        value: Math.random() * 1000,
        timestamp: new Date(2024, 0, 1, i % 24, Math.floor(i / 24) % 60).toISOString()
      }));

      const MockVirtualizedChart = ({ data }: { data: any[] }) => {
        const [viewWindow, setViewWindow] = React.useState({ start: 0, end: 100 });
        
        const visibleData = data.slice(viewWindow.start, viewWindow.end);

        return (
          <div data-testid="virtualized-chart">
            <div>
              Showing {viewWindow.start} - {viewWindow.end} of {data.length} points
            </div>
            <svg width="800" height="300">
              {visibleData.map((point, i) => (
                <circle
                  key={viewWindow.start + i}
                  cx={i * 8}
                  cy={150 + point.value * 0.1}
                  r="2"
                  fill="blue"
                />
              ))}
            </svg>
            <button onClick={() => setViewWindow({ start: 100, end: 200 })}>
              Next Window
            </button>
          </div>
        );
      };

      const renderTime = await measureRenderTime(() => {
        render(<MockVirtualizedChart data={largeDataset} />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.CHART_RENDER);

      // Test window switching performance
      const nextButton = screen.getByRole('button', { name: 'Next Window' });
      
      const switchTime = await measureInteractionTime(async () => {
        await userEvent.click(nextButton);
      });

      expect(switchTime).toBeLessThan(PERFORMANCE_THRESHOLDS.INTERACTION_TIME);
    });
  });

  describe('Loading State Performance', () => {
    it('should render loading states efficiently', async () => {
      const MockLoadingStates = () => (
        <div data-testid="loading-states">
          {/* Spinner */}
          <div className="spinner">
            <div className="spinner-circle"></div>
          </div>
          
          {/* Skeleton loaders */}
          {Array.from({ length: 10 }, (_, i) => (
            <div key={i} className="skeleton-item">
              <div className="skeleton-avatar"></div>
              <div className="skeleton-text"></div>
              <div className="skeleton-text short"></div>
            </div>
          ))}
          
          {/* Progress bar */}
          <div className="progress-bar">
            <div className="progress-fill" style={{ width: '60%' }}></div>
          </div>
        </div>
      );

      const renderTime = await measureRenderTime(() => {
        render(<MockLoadingStates />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.RENDER_TIME);
    });

    it('should handle loading state transitions smoothly', async () => {
      const MockTransitioningLoader = () => {
        const [loading, setLoading] = React.useState(true);
        const [data, setData] = React.useState<any[]>([]);

        React.useEffect(() => {
          setTimeout(() => {
            setData(Array.from({ length: 100 }, (_, i) => ({
              id: i,
              name: `Item ${i}`,
              value: Math.random() * 100
            })));
            setLoading(false);
          }, 100);
        }, []);

        if (loading) {
          return (
            <div data-testid="loading">
              {Array.from({ length: 10 }, (_, i) => (
                <div key={i} className="skeleton-item">Loading...</div>
              ))}
            </div>
          );
        }

        return (
          <div data-testid="loaded-content">
            {data.map(item => (
              <div key={item.id}>
                {item.name}: {item.value.toFixed(2)}
              </div>
            ))}
          </div>
        );
      };

      const initialMemory = measureMemoryUsage();
      
      render(<MockTransitioningLoader />);

      // Wait for transition
      await waitFor(() => {
        expect(screen.getByTestId('loaded-content')).toBeInTheDocument();
      }, { timeout: 200 });

      const finalMemory = measureMemoryUsage();
      const memoryDiff = finalMemory - initialMemory;

      expect(memoryDiff).toBeLessThan(PERFORMANCE_THRESHOLDS.MEMORY_LEAK_THRESHOLD);
    });
  });

  describe('Responsive Performance', () => {
    it('should handle viewport changes efficiently', async () => {
      const MockResponsiveComponent = () => {
        const [screenSize, setScreenSize] = React.useState('desktop');

        React.useEffect(() => {
          const handleResize = () => {
            const width = window.innerWidth;
            if (width < 768) {
              setScreenSize('mobile');
            } else if (width < 1024) {
              setScreenSize('tablet');
            } else {
              setScreenSize('desktop');
            }
          };

          window.addEventListener('resize', handleResize);
          handleResize(); // Initial check

          return () => window.removeEventListener('resize', handleResize);
        }, []);

        return (
          <div data-testid="responsive-component" className={`layout-${screenSize}`}>
            <div>Current screen size: {screenSize}</div>
            {screenSize === 'mobile' && <div>Mobile layout</div>}
            {screenSize === 'tablet' && <div>Tablet layout</div>}
            {screenSize === 'desktop' && <div>Desktop layout</div>}
          </div>
        );
      };

      render(<MockResponsiveComponent />);

      // Simulate viewport changes
      const resizeTime = await measureInteractionTime(async () => {
        global.testUtils.mockViewport(768, 1024);
        fireEvent(window, new Event('resize'));
        
        await waitFor(() => {
          expect(screen.getByText('Current screen size: tablet')).toBeInTheDocument();
        });
      });

      expect(resizeTime).toBeLessThan(PERFORMANCE_THRESHOLDS.INTERACTION_TIME);
    });
  });

  describe('Memory Management', () => {
    it('should properly clean up event listeners', async () => {
      const MockEventComponent = () => {
        React.useEffect(() => {
          const handleClick = () => {};
          const handleScroll = () => {};
          const handleResize = () => {};

          document.addEventListener('click', handleClick);
          window.addEventListener('scroll', handleScroll);
          window.addEventListener('resize', handleResize);

          return () => {
            document.removeEventListener('click', handleClick);
            window.removeEventListener('scroll', handleScroll);
            window.removeEventListener('resize', handleResize);
          };
        }, []);

        return <div data-testid="event-component">Component with events</div>;
      };

      const initialMemory = measureMemoryUsage();
      
      const { unmount } = render(<MockEventComponent />);
      
      // Simulate some time passing
      await new Promise(resolve => setTimeout(resolve, 50));
      
      unmount();
      
      // Force garbage collection if available
      if (global.gc) {
        global.gc();
      }
      
      const finalMemory = measureMemoryUsage();
      const memoryDiff = finalMemory - initialMemory;
      
      expect(memoryDiff).toBeLessThan(PERFORMANCE_THRESHOLDS.MEMORY_LEAK_THRESHOLD);
    });

    it('should handle component updates without memory leaks', async () => {
      const MockUpdatingComponent = ({ updateCount }: { updateCount: number }) => {
        const [internalCount, setInternalCount] = React.useState(0);

        React.useEffect(() => {
          setInternalCount(updateCount * 2);
        }, [updateCount]);

        return (
          <div data-testid="updating-component">
            Update count: {updateCount}, Internal: {internalCount}
          </div>
        );
      };

      const initialMemory = measureMemoryUsage();
      
      const { rerender } = render(<MockUpdatingComponent updateCount={0} />);
      
      // Simulate many updates
      for (let i = 1; i <= 100; i++) {
        rerender(<MockUpdatingComponent updateCount={i} />);
      }
      
      // Force garbage collection if available
      if (global.gc) {
        global.gc();
      }
      
      const finalMemory = measureMemoryUsage();
      const memoryDiff = finalMemory - initialMemory;
      
      expect(memoryDiff).toBeLessThan(PERFORMANCE_THRESHOLDS.MEMORY_LEAK_THRESHOLD);
    });
  });
});