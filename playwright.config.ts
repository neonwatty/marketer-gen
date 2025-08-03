import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  // Test directory
  testDir: './test/javascript/visual',
  
  // Timeout settings
  timeout: 30000,
  expect: {
    timeout: 10000,
    // Visual comparison threshold
    threshold: 0.2,
    // Enable visual comparisons
    toHaveScreenshot: {
      threshold: 0.2,
      mode: 'strict'
    }
  },
  
  // Global test setup
  globalSetup: './test/javascript/visual/globalSetup.ts',
  globalTeardown: './test/javascript/visual/globalTeardown.ts',
  
  // Test configuration
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  
  // Reporter configuration
  reporter: [
    ['html', { outputFolder: 'test-results/visual' }],
    ['junit', { outputFile: 'test-results/visual/results.xml' }],
    ['json', { outputFile: 'test-results/visual/results.json' }]
  ],
  
  // Global test settings
  use: {
    // Base URL for tests
    baseURL: 'http://localhost:3000',
    
    // Browser settings
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    
    // Viewport settings
    viewport: { width: 1280, height: 720 },
    
    // Ignore HTTPS errors
    ignoreHTTPSErrors: true,
    
    // Set user agent
    userAgent: 'Playwright-Test-Agent',
    
    // Extra HTTP headers
    extraHTTPHeaders: {
      'Accept-Language': 'en-US,en;q=0.9'
    }
  },

  // Test projects for different browsers and configurations
  projects: [
    // Desktop browsers
    {
      name: 'chromium-desktop',
      use: { 
        ...devices['Desktop Chrome'],
        viewport: { width: 1920, height: 1080 }
      }
    },
    {
      name: 'firefox-desktop',
      use: { 
        ...devices['Desktop Firefox'],
        viewport: { width: 1920, height: 1080 }
      }
    },
    {
      name: 'webkit-desktop',
      use: { 
        ...devices['Desktop Safari'],
        viewport: { width: 1920, height: 1080 }
      }
    },
    {
      name: 'edge-desktop',
      use: { 
        ...devices['Desktop Edge'],
        viewport: { width: 1920, height: 1080 }
      }
    },
    
    // Tablet devices
    {
      name: 'ipad',
      use: { ...devices['iPad Pro'] }
    },
    {
      name: 'tablet-android',
      use: { ...devices['Galaxy Tab S4'] }
    },
    
    // Mobile devices
    {
      name: 'iphone',
      use: { ...devices['iPhone 13'] }
    },
    {
      name: 'pixel',
      use: { ...devices['Pixel 5'] }
    },
    
    // Custom responsive breakpoints
    {
      name: 'mobile-320',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 320, height: 568 },
        isMobile: true,
        hasTouch: true
      }
    },
    {
      name: 'tablet-768',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 768, height: 1024 },
        isMobile: true,
        hasTouch: true
      }
    },
    {
      name: 'desktop-1024',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 1024, height: 768 }
      }
    },
    {
      name: 'desktop-1440',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 1440, height: 900 }
      }
    },
    {
      name: 'ultrawide-2560',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 2560, height: 1440 }
      }
    },
    
    // Dark theme testing
    {
      name: 'dark-theme-desktop',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 1920, height: 1080 },
        colorScheme: 'dark'
      }
    },
    {
      name: 'dark-theme-mobile',
      use: {
        ...devices['iPhone 13'],
        colorScheme: 'dark'
      }
    },
    
    // High contrast testing
    {
      name: 'high-contrast',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 1920, height: 1080 },
        forcedColors: 'active'
      }
    },
    
    // Reduced motion testing
    {
      name: 'reduced-motion',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 1920, height: 1080 },
        reducedMotion: 'reduce'
      }
    }
  ],

  // Rails dev server - assumes Rails server is running
  webServer: process.env.CI ? {
    command: 'rails server -e test -p 3000',
    port: 3000,
    reuseExistingServer: false,
    timeout: 120000,
    env: {
      RAILS_ENV: 'test'
    }
  } : undefined
});