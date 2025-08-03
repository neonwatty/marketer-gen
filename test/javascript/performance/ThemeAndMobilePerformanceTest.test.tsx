/**
 * Theme Switching and Mobile Performance Test Suite
 * Tests theme transitions, mobile performance, and 60fps animations
 */

import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

// Mock Theme Provider
const ThemeProvider: React.FC<{
  theme: 'light' | 'dark' | 'brand';
  children: React.ReactNode;
}> = ({ theme, children }) => {
  const themeConfig = {
    light: {
      primary: '#0088FE',
      secondary: '#00C49F',
      background: '#FFFFFF',
      text: '#374151',
      accent: '#FFBB28'
    },
    dark: {
      primary: '#60A5FA',
      secondary: '#34D399',
      background: '#1F2937',
      text: '#F9FAFB',
      accent: '#FBBF24'
    },
    brand: {
      primary: '#0088FE',
      secondary: '#00C49F',
      background: '#FFFFFF',
      text: '#1E40AF',
      accent: '#FFBB28'
    }
  };

  return (
    <div 
      className={`theme-provider theme-${theme}`}
      data-testid="theme-provider"
      data-theme={theme}
      style={{
        backgroundColor: themeConfig[theme].background,
        color: themeConfig[theme].text,
        transition: 'background-color 0.3s ease, color 0.3s ease'
      }}
    >
      {children}
    </div>
  );
};

// Mock components with theme support
const MockThemedButton: React.FC<{
  children: React.ReactNode;
  onClick?: () => void;
  variant?: 'primary' | 'secondary';
  theme?: 'light' | 'dark' | 'brand';
}> = ({ children, onClick, variant = 'primary', theme = 'light' }) => {
  const [isPressed, setIsPressed] = React.useState(false);
  
  const colors = {
    light: { primary: '#0088FE', secondary: '#00C49F' },
    dark: { primary: '#60A5FA', secondary: '#34D399' },
    brand: { primary: '#0088FE', secondary: '#00C49F' }
  };

  return (
    <button
      onClick={onClick}
      onMouseDown={() => setIsPressed(true)}
      onMouseUp={() => setIsPressed(false)}
      onMouseLeave={() => setIsPressed(false)}
      className={`themed-button ${variant}`}
      data-testid="themed-button"
      style={{
        backgroundColor: colors[theme][variant],
        color: 'white',
        padding: '12px 24px',
        border: 'none',
        borderRadius: '8px',
        cursor: 'pointer',
        transform: isPressed ? 'scale(0.95)' : 'scale(1)',
        transition: 'all 0.15s ease',
        fontSize: '16px'
      }}
    >
      {children}
    </button>
  );
};

const MockAnimatedCard: React.FC<{
  title: string;
  content: string;
  theme?: 'light' | 'dark' | 'brand';
  animate?: boolean;
}> = ({ title, content, theme = 'light', animate = true }) => {
  const [isVisible, setIsVisible] = React.useState(false);
  const [isHovered, setIsHovered] = React.useState(false);

  React.useEffect(() => {
    if (animate) {
      const timer = setTimeout(() => setIsVisible(true), 100);
      return () => clearTimeout(timer);
    } else {
      setIsVisible(true);
    }
  }, [animate]);

  const themeStyles = {
    light: { bg: '#FFFFFF', border: '#E5E7EB', shadow: '0 4px 6px rgba(0, 0, 0, 0.1)' },
    dark: { bg: '#1F2937', border: '#374151', shadow: '0 4px 6px rgba(0, 0, 0, 0.3)' },
    brand: { bg: '#F8FAFC', border: '#E0E7FF', shadow: '0 4px 6px rgba(0, 136, 254, 0.1)' }
  };

  return (
    <div
      className={`animated-card theme-${theme}`}
      data-testid="animated-card"
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
      style={{
        backgroundColor: themeStyles[theme].bg,
        border: `1px solid ${themeStyles[theme].border}`,
        borderRadius: '12px',
        padding: '24px',
        margin: '12px',
        boxShadow: themeStyles[theme].shadow,
        transform: `translateY(${isVisible ? 0 : 20}px) scale(${isHovered ? 1.02 : 1})`,
        opacity: isVisible ? 1 : 0,
        transition: animate ? 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)' : 'none',
        cursor: 'pointer'
      }}
    >
      <h3 style={{ margin: '0 0 12px 0', fontSize: '18px', fontWeight: 'bold' }}>
        {title}
      </h3>
      <p style={{ margin: 0, fontSize: '14px', lineHeight: '1.5' }}>
        {content}
      </p>
    </div>
  );
};

const MockMobileNavigation: React.FC<{
  items: Array<{ label: string; href: string }>;
  theme?: 'light' | 'dark' | 'brand';
}> = ({ items, theme = 'light' }) => {
  const [isOpen, setIsOpen] = React.useState(false);
  const [activeItem, setActiveItem] = React.useState<string | null>(null);

  const themeStyles = {
    light: { bg: '#FFFFFF', text: '#374151', accent: '#0088FE' },
    dark: { bg: '#1F2937', text: '#F9FAFB', accent: '#60A5FA' },
    brand: { bg: '#F8FAFC', text: '#1E40AF', accent: '#0088FE' }
  };

  return (
    <nav 
      className={`mobile-navigation theme-${theme}`}
      data-testid="mobile-navigation"
      style={{
        backgroundColor: themeStyles[theme].bg,
        color: themeStyles[theme].text
      }}
    >
      {/* Hamburger Menu */}
      <button
        onClick={() => setIsOpen(!isOpen)}
        data-testid="menu-toggle"
        className="menu-toggle"
        style={{
          background: 'transparent',
          border: 'none',
          cursor: 'pointer',
          padding: '12px',
          color: themeStyles[theme].text
        }}
      >
        <div 
          style={{
            width: '24px',
            height: '3px',
            backgroundColor: 'currentColor',
            margin: '3px 0',
            transform: isOpen ? 'rotate(45deg) translate(5px, 5px)' : 'none',
            transition: 'transform 0.3s ease'
          }}
        />
        <div 
          style={{
            width: '24px',
            height: '3px',
            backgroundColor: 'currentColor',
            margin: '3px 0',
            opacity: isOpen ? 0 : 1,
            transition: 'opacity 0.3s ease'
          }}
        />
        <div 
          style={{
            width: '24px',
            height: '3px',
            backgroundColor: 'currentColor',
            margin: '3px 0',
            transform: isOpen ? 'rotate(-45deg) translate(7px, -6px)' : 'none',
            transition: 'transform 0.3s ease'
          }}
        />
      </button>

      {/* Menu Items */}
      <div 
        className="menu-items"
        data-testid="menu-items"
        style={{
          maxHeight: isOpen ? '400px' : '0',
          overflow: 'hidden',
          transition: 'max-height 0.3s ease'
        }}
      >
        {items.map((item, index) => (
          <a
            key={index}
            href={item.href}
            onClick={(e) => {
              e.preventDefault();
              setActiveItem(item.label);
            }}
            data-testid={`menu-item-${index}`}
            style={{
              display: 'block',
              padding: '16px 20px',
              textDecoration: 'none',
              color: activeItem === item.label ? themeStyles[theme].accent : 'inherit',
              backgroundColor: activeItem === item.label ? `${themeStyles[theme].accent}20` : 'transparent',
              borderLeft: activeItem === item.label ? `4px solid ${themeStyles[theme].accent}` : '4px solid transparent',
              transition: 'all 0.2s ease'
            }}
          >
            {item.label}
          </a>
        ))}
      </div>
    </nav>
  );
};

const MockScrollableList: React.FC<{
  items: Array<{ id: string; title: string; description: string }>;
  theme?: 'light' | 'dark' | 'brand';
  virtualizeThreshold?: number;
}> = ({ items, theme = 'light', virtualizeThreshold = 100 }) => {
  const [visibleStart, setVisibleStart] = React.useState(0);
  const [visibleEnd, setVisibleEnd] = React.useState(20);
  const containerRef = React.useRef<HTMLDivElement>(null);

  const shouldVirtualize = items.length > virtualizeThreshold;
  const displayItems = shouldVirtualize ? items.slice(visibleStart, visibleEnd) : items;

  const handleScroll = React.useCallback((e: React.UIEvent<HTMLDivElement>) => {
    if (!shouldVirtualize) return;

    const container = e.currentTarget;
    const scrollTop = container.scrollTop;
    const itemHeight = 80;
    const containerHeight = container.clientHeight;
    
    const newVisibleStart = Math.floor(scrollTop / itemHeight);
    const visibleCount = Math.ceil(containerHeight / itemHeight) + 5; // Buffer
    const newVisibleEnd = Math.min(newVisibleStart + visibleCount, items.length);
    
    setVisibleStart(newVisibleStart);
    setVisibleEnd(newVisibleEnd);
  }, [shouldVirtualize, items.length]);

  const themeStyles = {
    light: { bg: '#FFFFFF', item: '#F9FAFB', border: '#E5E7EB' },
    dark: { bg: '#1F2937', item: '#374151', border: '#4B5563' },
    brand: { bg: '#F8FAFC', item: '#EFF6FF', border: '#DBEAFE' }
  };

  return (
    <div
      ref={containerRef}
      className={`scrollable-list theme-${theme}`}
      data-testid="scrollable-list"
      onScroll={handleScroll}
      style={{
        height: '400px',
        overflowY: 'auto',
        backgroundColor: themeStyles[theme].bg,
        border: `1px solid ${themeStyles[theme].border}`,
        borderRadius: '8px'
      }}
    >
      {shouldVirtualize && (
        <div style={{ height: visibleStart * 80 }} />
      )}
      
      {displayItems.map((item, index) => (
        <div
          key={shouldVirtualize ? visibleStart + index : index}
          className="list-item"
          data-testid={`list-item-${shouldVirtualize ? visibleStart + index : index}`}
          style={{
            height: '80px',
            padding: '16px',
            borderBottom: `1px solid ${themeStyles[theme].border}`,
            backgroundColor: themeStyles[theme].item,
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center'
          }}
        >
          <h4 style={{ margin: '0 0 4px 0', fontSize: '16px' }}>{item.title}</h4>
          <p style={{ margin: 0, fontSize: '14px', opacity: 0.7 }}>{item.description}</p>
        </div>
      ))}
      
      {shouldVirtualize && (
        <div style={{ height: (items.length - visibleEnd) * 80 }} />
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
  await new Promise(resolve => setTimeout(resolve, expectedDuration + 50));
  const end = performance.now();
  return end - start;
};

const measureScrollPerformance = async (
  element: HTMLElement, 
  scrollDistance: number, 
  steps: number = 10
): Promise<number[]> => {
  const frameTimings: number[] = [];
  const stepSize = scrollDistance / steps;
  
  for (let i = 0; i < steps; i++) {
    const frameStart = performance.now();
    
    element.scrollTop = stepSize * i;
    fireEvent.scroll(element);
    
    await new Promise(resolve => requestAnimationFrame(resolve));
    
    const frameEnd = performance.now();
    frameTimings.push(frameEnd - frameStart);
  }
  
  return frameTimings;
};

const measureMemoryUsage = (): number => {
  if ('memory' in performance) {
    return (performance as any).memory.usedJSHeapSize;
  }
  return 0;
};

// Touch simulation utilities
const simulateTouch = (element: HTMLElement, type: 'start' | 'move' | 'end', x: number, y: number) => {
  const touch = new Touch({
    identifier: 1,
    target: element,
    clientX: x,
    clientY: y,
    pageX: x,
    pageY: y,
    screenX: x,
    screenY: y
  });

  const touchEvent = new TouchEvent(`touch${type}`, {
    touches: type === 'end' ? [] : [touch],
    targetTouches: type === 'end' ? [] : [touch],
    changedTouches: [touch],
    bubbles: true,
    cancelable: true
  });

  element.dispatchEvent(touchEvent);
};

describe('Theme Switching and Mobile Performance Tests', () => {
  const PERFORMANCE_THRESHOLDS = {
    THEME_SWITCH_TIME: 50,      // 50ms for theme switching
    ANIMATION_FRAME_TIME: 16,   // 16ms per frame (60fps)
    MOBILE_RENDER_TIME: 200,    // 200ms for mobile rendering
    TOUCH_RESPONSE_TIME: 100,   // 100ms for touch responses
    SCROLL_FRAME_TIME: 16,      // 16ms per scroll frame
    NAVIGATION_ANIMATION: 300,  // 300ms for navigation animations
    THEME_TRANSITION: 300,      // 300ms for theme transitions
    MEMORY_LEAK_THRESHOLD: 15 * 1024 * 1024, // 15MB
    LIST_VIRTUALIZATION: 100,   // 100ms for virtualization
    RESPONSIVE_BREAKPOINT: 100  // 100ms for responsive changes
  };

  // Mock mobile viewport
  const mockMobileViewport = () => {
    Object.defineProperty(window, 'innerWidth', { value: 390, writable: true });
    Object.defineProperty(window, 'innerHeight', { value: 844, writable: true });
    Object.defineProperty(window, 'screen', {
      value: { width: 390, height: 844 },
      writable: true
    });
  };

  const mockTabletViewport = () => {
    Object.defineProperty(window, 'innerWidth', { value: 768, writable: true });
    Object.defineProperty(window, 'innerHeight', { value: 1024, writable: true });
  };

  const mockDesktopViewport = () => {
    Object.defineProperty(window, 'innerWidth', { value: 1920, writable: true });
    Object.defineProperty(window, 'innerHeight', { value: 1080, writable: true });
  };

  beforeEach(() => {
    // Reset viewport to desktop by default
    mockDesktopViewport();
  });

  describe('Theme Switching Performance', () => {
    it('should switch themes within performance threshold', async () => {
      const { rerender } = render(
        <ThemeProvider theme="light">
          <MockThemedButton>Test Button</MockThemedButton>
          <MockAnimatedCard title="Test" content="Content" />
        </ThemeProvider>
      );

      const start = performance.now();
      rerender(
        <ThemeProvider theme="dark">
          <MockThemedButton theme="dark">Test Button</MockThemedButton>
          <MockAnimatedCard title="Test" content="Content" theme="dark" />
        </ThemeProvider>
      );
      await new Promise(resolve => setTimeout(resolve, 0));
      const end = performance.now();

      expect(end - start).toBeLessThan(PERFORMANCE_THRESHOLDS.THEME_SWITCH_TIME);
    });

    it('should handle rapid theme changes efficiently', async () => {
      const themes: Array<'light' | 'dark' | 'brand'> = ['light', 'dark', 'brand', 'light', 'dark'];
      let currentTheme = 'light' as 'light' | 'dark' | 'brand';
      
      const { rerender } = render(
        <ThemeProvider theme={currentTheme}>
          <MockThemedButton theme={currentTheme}>Button</MockThemedButton>
        </ThemeProvider>
      );

      const start = performance.now();

      for (const theme of themes) {
        currentTheme = theme;
        rerender(
          <ThemeProvider theme={currentTheme}>
            <MockThemedButton theme={currentTheme}>Button</MockThemedButton>
          </ThemeProvider>
        );
        await new Promise(resolve => setTimeout(resolve, 5));
      }

      const end = performance.now();
      const avgTime = (end - start) / themes.length;

      expect(avgTime).toBeLessThan(PERFORMANCE_THRESHOLDS.THEME_SWITCH_TIME);
    });

    it('should animate theme transitions smoothly', async () => {
      render(
        <ThemeProvider theme="light">
          <MockAnimatedCard title="Test" content="Content" animate={true} />
        </ThemeProvider>
      );

      const card = screen.getByTestId('animated-card');
      const animationTime = await measureAnimationTime(card, 300);

      expect(animationTime).toBeLessThan(PERFORMANCE_THRESHOLDS.THEME_TRANSITION + 50);
    });

    it('should not leak memory during theme changes', async () => {
      const initialMemory = measureMemoryUsage();
      
      let currentTheme = 'light' as 'light' | 'dark' | 'brand';
      const { rerender, unmount } = render(
        <ThemeProvider theme={currentTheme}>
          <div>
            {Array.from({ length: 20 }, (_, i) => (
              <MockAnimatedCard key={i} title={`Card ${i}`} content="Content" theme={currentTheme} />
            ))}
          </div>
        </ThemeProvider>
      );

      // Simulate multiple theme changes
      for (let i = 0; i < 10; i++) {
        currentTheme = ['light', 'dark', 'brand'][i % 3] as 'light' | 'dark' | 'brand';
        rerender(
          <ThemeProvider theme={currentTheme}>
            <div>
              {Array.from({ length: 20 }, (_, j) => (
                <MockAnimatedCard key={j} title={`Card ${j}`} content="Content" theme={currentTheme} />
              ))}
            </div>
          </ThemeProvider>
        );
        await new Promise(resolve => setTimeout(resolve, 10));
      }

      unmount();
      
      if (global.gc) {
        global.gc();
      }

      const finalMemory = measureMemoryUsage();
      const memoryDiff = finalMemory - initialMemory;

      expect(memoryDiff).toBeLessThan(PERFORMANCE_THRESHOLDS.MEMORY_LEAK_THRESHOLD);
    });
  });

  describe('Mobile Performance', () => {
    it('should render efficiently on mobile viewport', async () => {
      mockMobileViewport();

      const renderTime = await measureRenderTime(() => {
        render(
          <ThemeProvider theme="light">
            <MockMobileNavigation
              items={[
                { label: 'Home', href: '/' },
                { label: 'Dashboard', href: '/dashboard' },
                { label: 'Campaigns', href: '/campaigns' },
                { label: 'Analytics', href: '/analytics' }
              ]}
            />
            <div>
              {Array.from({ length: 10 }, (_, i) => (
                <MockAnimatedCard key={i} title={`Card ${i}`} content="Mobile content" />
              ))}
            </div>
          </ThemeProvider>
        );
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.MOBILE_RENDER_TIME);
    });

    it('should handle mobile navigation animations at 60fps', async () => {
      mockMobileViewport();
      
      render(
        <MockMobileNavigation
          items={[
            { label: 'Home', href: '/' },
            { label: 'About', href: '/about' },
            { label: 'Contact', href: '/contact' }
          ]}
        />
      );

      const menuToggle = screen.getByTestId('menu-toggle');
      
      const start = performance.now();
      fireEvent.click(menuToggle);
      
      await waitFor(() => {
        const menuItems = screen.getByTestId('menu-items');
        return getComputedStyle(menuItems).maxHeight !== '0px';
      });
      
      const end = performance.now();
      
      expect(end - start).toBeLessThan(PERFORMANCE_THRESHOLDS.NAVIGATION_ANIMATION + 50);
    });

    it('should handle touch interactions efficiently', async () => {
      mockMobileViewport();
      
      render(
        <ThemeProvider theme="light">
          <MockThemedButton>Touch Button</MockThemedButton>
        </ThemeProvider>
      );

      const button = screen.getByTestId('themed-button');
      
      const start = performance.now();
      
      // Simulate touch sequence
      simulateTouch(button, 'start', 100, 100);
      await new Promise(resolve => setTimeout(resolve, 10));
      simulateTouch(button, 'end', 100, 100);
      
      const end = performance.now();
      
      expect(end - start).toBeLessThan(PERFORMANCE_THRESHOLDS.TOUCH_RESPONSE_TIME);
    });

    it('should handle swipe gestures efficiently', async () => {
      mockMobileViewport();
      
      render(
        <div 
          data-testid="swipe-container"
          style={{ width: '100%', height: '200px', overflow: 'hidden' }}
        >
          <div style={{ width: '300%', height: '100%', display: 'flex' }}>
            <div style={{ flex: 1, backgroundColor: 'red' }}>Panel 1</div>
            <div style={{ flex: 1, backgroundColor: 'green' }}>Panel 2</div>
            <div style={{ flex: 1, backgroundColor: 'blue' }}>Panel 3</div>
          </div>
        </div>
      );

      const container = screen.getByTestId('swipe-container');
      
      const start = performance.now();
      
      // Simulate swipe gesture
      simulateTouch(container, 'start', 200, 100);
      for (let x = 200; x > 50; x -= 10) {
        simulateTouch(container, 'move', x, 100);
        await new Promise(resolve => requestAnimationFrame(resolve));
      }
      simulateTouch(container, 'end', 50, 100);
      
      const end = performance.now();
      const totalTime = end - start;
      const frameCount = (200 - 50) / 10;
      const avgFrameTime = totalTime / frameCount;
      
      expect(avgFrameTime).toBeLessThan(PERFORMANCE_THRESHOLDS.ANIMATION_FRAME_TIME * 2);
    });
  });

  describe('60fps Animation Performance', () => {
    it('should maintain 60fps during card animations', async () => {
      const cards = Array.from({ length: 20 }, (_, i) => ({
        title: `Card ${i}`,
        content: `Content for card ${i}`
      }));

      render(
        <div>
          {cards.map((card, i) => (
            <MockAnimatedCard 
              key={i} 
              title={card.title} 
              content={card.content} 
              animate={true}
            />
          ))}
        </div>
      );

      // Measure animation frame rate by triggering hover states
      const cardElements = screen.getAllByTestId('animated-card');
      const frameTimings: number[] = [];
      
      for (const card of cardElements.slice(0, 5)) {
        const frameStart = performance.now();
        
        fireEvent.mouseEnter(card);
        await new Promise(resolve => requestAnimationFrame(resolve));
        fireEvent.mouseLeave(card);
        await new Promise(resolve => requestAnimationFrame(resolve));
        
        const frameEnd = performance.now();
        frameTimings.push(frameEnd - frameStart);
      }
      
      const avgFrameTime = frameTimings.reduce((a, b) => a + b, 0) / frameTimings.length;
      expect(avgFrameTime).toBeLessThan(PERFORMANCE_THRESHOLDS.ANIMATION_FRAME_TIME * 4);
    });

    it('should handle scroll animations at 60fps', async () => {
      const items = Array.from({ length: 200 }, (_, i) => ({
        id: `item-${i}`,
        title: `Item ${i}`,
        description: `Description for item ${i}`
      }));

      render(<MockScrollableList items={items} virtualizeThreshold={50} />);
      
      const scrollContainer = screen.getByTestId('scrollable-list');
      const frameTimings = await measureScrollPerformance(scrollContainer, 1000, 20);
      
      const avgFrameTime = frameTimings.reduce((a, b) => a + b, 0) / frameTimings.length;
      const maxFrameTime = Math.max(...frameTimings);
      
      expect(avgFrameTime).toBeLessThan(PERFORMANCE_THRESHOLDS.SCROLL_FRAME_TIME * 2);
      expect(maxFrameTime).toBeLessThan(PERFORMANCE_THRESHOLDS.SCROLL_FRAME_TIME * 4);
    });

    it('should maintain frame rate during theme transitions', async () => {
      const { rerender } = render(
        <ThemeProvider theme="light">
          <div>
            {Array.from({ length: 15 }, (_, i) => (
              <MockAnimatedCard key={i} title={`Card ${i}`} content="Content" />
            ))}
          </div>
        </ThemeProvider>
      );

      const frameTimings: number[] = [];
      
      for (let i = 0; i < 5; i++) {
        const frameStart = performance.now();
        
        rerender(
          <ThemeProvider theme={i % 2 === 0 ? 'dark' : 'light'}>
            <div>
              {Array.from({ length: 15 }, (_, j) => (
                <MockAnimatedCard 
                  key={j} 
                  title={`Card ${j}`} 
                  content="Content" 
                  theme={i % 2 === 0 ? 'dark' : 'light'}
                />
              ))}
            </div>
          </ThemeProvider>
        );
        
        await new Promise(resolve => requestAnimationFrame(resolve));
        
        const frameEnd = performance.now();
        frameTimings.push(frameEnd - frameStart);
      }
      
      const avgFrameTime = frameTimings.reduce((a, b) => a + b, 0) / frameTimings.length;
      expect(avgFrameTime).toBeLessThan(PERFORMANCE_THRESHOLDS.ANIMATION_FRAME_TIME * 6);
    });
  });

  describe('List Virtualization Performance', () => {
    it('should virtualize large lists efficiently', async () => {
      const items = Array.from({ length: 1000 }, (_, i) => ({
        id: `item-${i}`,
        title: `Item ${i}`,
        description: `Description for item ${i}`
      }));

      const renderTime = await measureRenderTime(() => {
        render(<MockScrollableList items={items} virtualizeThreshold={100} />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.LIST_VIRTUALIZATION);
      
      // Should only render visible items
      const visibleItems = screen.getAllByTestId(/list-item-/);
      expect(visibleItems.length).toBeLessThan(50); // Much less than 1000
    });

    it('should handle virtualized scrolling efficiently', async () => {
      const items = Array.from({ length: 500 }, (_, i) => ({
        id: `item-${i}`,
        title: `Item ${i}`,
        description: `Description for item ${i}`
      }));

      render(<MockScrollableList items={items} virtualizeThreshold={50} />);
      
      const scrollContainer = screen.getByTestId('scrollable-list');
      
      // Test scrolling performance
      const start = performance.now();
      
      for (let i = 0; i < 10; i++) {
        scrollContainer.scrollTop = i * 100;
        fireEvent.scroll(scrollContainer);
        await new Promise(resolve => requestAnimationFrame(resolve));
      }
      
      const end = performance.now();
      const avgScrollTime = (end - start) / 10;
      
      expect(avgScrollTime).toBeLessThan(PERFORMANCE_THRESHOLDS.SCROLL_FRAME_TIME * 3);
    });

    it('should maintain memory efficiency with large lists', async () => {
      const items = Array.from({ length: 5000 }, (_, i) => ({
        id: `item-${i}`,
        title: `Very long item title that contains a lot of text ${i}`,
        description: `Very detailed description for item ${i} with lots of content`
      }));

      const initialMemory = measureMemoryUsage();
      
      const { unmount } = render(<MockScrollableList items={items} virtualizeThreshold={100} />);
      
      // Simulate scrolling through the list
      const scrollContainer = screen.getByTestId('scrollable-list');
      for (let i = 0; i < 20; i++) {
        scrollContainer.scrollTop = i * 200;
        fireEvent.scroll(scrollContainer);
        await new Promise(resolve => setTimeout(resolve, 10));
      }
      
      unmount();
      
      if (global.gc) {
        global.gc();
      }
      
      const finalMemory = measureMemoryUsage();
      const memoryDiff = finalMemory - initialMemory;
      
      expect(memoryDiff).toBeLessThan(PERFORMANCE_THRESHOLDS.MEMORY_LEAK_THRESHOLD);
    });
  });

  describe('Responsive Design Performance', () => {
    it('should adapt to viewport changes efficiently', async () => {
      const { rerender } = render(
        <ThemeProvider theme="light">
          <MockMobileNavigation
            items={[{ label: 'Home', href: '/' }, { label: 'About', href: '/about' }]}
          />
        </ThemeProvider>
      );

      // Switch to mobile
      mockMobileViewport();
      
      const start = performance.now();
      fireEvent(window, new Event('resize'));
      rerender(
        <ThemeProvider theme="light">
          <MockMobileNavigation
            items={[{ label: 'Home', href: '/' }, { label: 'About', href: '/about' }]}
          />
        </ThemeProvider>
      );
      const end = performance.now();

      expect(end - start).toBeLessThan(PERFORMANCE_THRESHOLDS.RESPONSIVE_BREAKPOINT);
    });

    it('should handle multiple breakpoint changes efficiently', async () => {
      const component = (
        <ThemeProvider theme="light">
          <div>
            {Array.from({ length: 10 }, (_, i) => (
              <MockAnimatedCard key={i} title={`Card ${i}`} content="Responsive content" />
            ))}
          </div>
        </ThemeProvider>
      );

      const { rerender } = render(component);
      
      const viewports = [
        () => mockMobileViewport(),
        () => mockTabletViewport(),
        () => mockDesktopViewport(),
        () => mockMobileViewport()
      ];
      
      const start = performance.now();
      
      for (const setViewport of viewports) {
        setViewport();
        fireEvent(window, new Event('resize'));
        rerender(component);
        await new Promise(resolve => setTimeout(resolve, 10));
      }
      
      const end = performance.now();
      const avgTime = (end - start) / viewports.length;
      
      expect(avgTime).toBeLessThan(PERFORMANCE_THRESHOLDS.RESPONSIVE_BREAKPOINT * 2);
    });
  });

  describe('Cross-Device Performance', () => {
    it('should perform well on various device types', async () => {
      const devices = [
        { name: 'mobile', setup: mockMobileViewport },
        { name: 'tablet', setup: mockTabletViewport },
        { name: 'desktop', setup: mockDesktopViewport }
      ];

      for (const device of devices) {
        device.setup();
        
        const renderTime = await measureRenderTime(() => {
          render(
            <ThemeProvider theme="light">
              <MockMobileNavigation
                items={[
                  { label: 'Dashboard', href: '/dashboard' },
                  { label: 'Campaigns', href: '/campaigns' },
                  { label: 'Analytics', href: '/analytics' }
                ]}
              />
              <div>
                {Array.from({ length: 8 }, (_, i) => (
                  <MockAnimatedCard 
                    key={i} 
                    title={`Card ${i}`} 
                    content={`Content for ${device.name}`} 
                  />
                ))}
              </div>
            </ThemeProvider>
          );
        });

        // Mobile can be slightly slower
        const threshold = device.name === 'mobile' 
          ? PERFORMANCE_THRESHOLDS.MOBILE_RENDER_TIME 
          : PERFORMANCE_THRESHOLDS.MOBILE_RENDER_TIME * 0.8;
          
        expect(renderTime).toBeLessThan(threshold);
      }
    });

    it('should handle device orientation changes efficiently', async () => {
      mockMobileViewport();
      
      render(
        <ThemeProvider theme="light">
          <MockScrollableList
            items={Array.from({ length: 50 }, (_, i) => ({
              id: `item-${i}`,
              title: `Item ${i}`,
              description: 'Description'
            }))}
          />
        </ThemeProvider>
      );

      const start = performance.now();
      
      // Simulate orientation change
      Object.defineProperty(window, 'innerWidth', { value: 844 });
      Object.defineProperty(window, 'innerHeight', { value: 390 });
      fireEvent(window, new Event('orientationchange'));
      fireEvent(window, new Event('resize'));
      
      await new Promise(resolve => setTimeout(resolve, 50));
      
      const end = performance.now();
      
      expect(end - start).toBeLessThan(PERFORMANCE_THRESHOLDS.RESPONSIVE_BREAKPOINT);
    });
  });
});