import '@testing-library/jest-dom';
import 'jest-axe/extend-expect';

// Mock window.matchMedia for responsive tests
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: jest.fn().mockImplementation(query => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: jest.fn(), // deprecated
    removeListener: jest.fn(), // deprecated
    addEventListener: jest.fn(),
    removeEventListener: jest.fn(),
    dispatchEvent: jest.fn(),
  })),
});

// Mock ResizeObserver for responsive components
global.ResizeObserver = jest.fn().mockImplementation(() => ({
  observe: jest.fn(),
  unobserve: jest.fn(),
  disconnect: jest.fn(),
}));

// Mock IntersectionObserver for lazy loading components
global.IntersectionObserver = jest.fn().mockImplementation(() => ({
  observe: jest.fn(),
  unobserve: jest.fn(),
  disconnect: jest.fn(),
}));

// Mock ScrollIntoView for navigation tests
Element.prototype.scrollIntoView = jest.fn();

// Mock PerformanceObserver for performance tests
global.PerformanceObserver = jest.fn().mockImplementation(() => ({
  observe: jest.fn(),
  disconnect: jest.fn(),
}));

// Mock Web APIs commonly used in UI components
global.HTMLCanvasElement.prototype.getContext = jest.fn();
global.HTMLMediaElement.prototype.load = () => {};
global.HTMLMediaElement.prototype.play = () => Promise.resolve();
global.HTMLMediaElement.prototype.pause = () => {};

// Mock fetch for API tests
global.fetch = jest.fn();

// Mock console.warn for cleaner test output
const originalWarn = console.warn;
beforeAll(() => {
  console.warn = (...args: any[]) => {
    if (
      typeof args[0] === 'string' &&
      args[0].includes('componentWillReceiveProps') ||
      args[0].includes('Warning: ReactDOM.render is no longer supported')
    ) {
      // Suppress React warnings in tests
      return;
    }
    originalWarn.call(console, ...args);
  };
});

afterAll(() => {
  console.warn = originalWarn;
});

// Performance tracking utilities for tests
global.testUtils = {
  measureRenderTime: async (renderFn: () => Promise<void> | void) => {
    const start = performance.now();
    await renderFn();
    const end = performance.now();
    return end - start;
  },
  
  mockViewport: (width: number, height: number) => {
    Object.defineProperty(window, 'innerWidth', {
      writable: true,
      configurable: true,
      value: width,
    });
    Object.defineProperty(window, 'innerHeight', {
      writable: true,
      configurable: true,
      value: height,
    });
    window.dispatchEvent(new Event('resize'));
  },
  
  waitForNextTick: () => new Promise(resolve => setTimeout(resolve, 0)),
};

// Accessibility test utilities
global.axeConfig = {
  rules: {
    // Configure axe-core rules for WCAG 2.1 AA compliance
    'color-contrast': { enabled: true },
    'aria-allowed-attr': { enabled: true },
    'aria-required-attr': { enabled: true },
    'aria-roles': { enabled: true },
    'aria-valid-attr': { enabled: true },
    'aria-valid-attr-value': { enabled: true },
    'button-name': { enabled: true },
    'bypass': { enabled: true },
    'document-title': { enabled: true },
    'duplicate-id': { enabled: true },
    'form-field-multiple-labels': { enabled: true },
    'html-has-lang': { enabled: true },
    'html-lang-valid': { enabled: true },
    'image-alt': { enabled: true },
    'input-image-alt': { enabled: true },
    'label': { enabled: true },
    'link-name': { enabled: true },
    'list': { enabled: true },
    'listitem': { enabled: true },
    'meta-refresh': { enabled: true },
    'meta-viewport': { enabled: true },
    'object-alt': { enabled: true },
    'role-img-alt': { enabled: true },
    'scrollable-region-focusable': { enabled: true },
    'select-name': { enabled: true },
    'server-side-image-map': { enabled: true },
    'svg-img-alt': { enabled: true },
    'td-headers-attr': { enabled: true },
    'th-has-data-cells': { enabled: true },
    'valid-lang': { enabled: true },
    'video-caption': { enabled: true },
  }
};

// Mock environment variables
process.env.NODE_ENV = 'test';
process.env.RAILS_ENV = 'test';

// Global test configuration
jest.setTimeout(10000);