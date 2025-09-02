import { defineConfig, devices } from '@playwright/test';

/**
 * See https://playwright.dev/docs/test-configuration.
 */
export default defineConfig({
  testDir: './tests/playwright-ai-workflows',
  /* Run tests in files in parallel */
  fullyParallel: true,
  /* Fail the build on CI if you accidentally left test.only in the source code. */
  forbidOnly: !!process.env.CI,
  /* Retry on CI only */
  retries: process.env.CI ? 2 : 0,
  /* Opt out of parallel tests on CI. */
  workers: process.env.CI ? 1 : undefined,
  /* Reporter to use. See https://playwright.dev/docs/test-reporters */
  reporter: 'html',
  /* Shared settings for all the projects below. See https://playwright.dev/docs/api/class-testoptions. */
  use: {
    /* Base URL to use in actions like `await page.goto('/')`. */
    baseURL: process.env.BASE_URL || 'http://localhost:3001',

    /* Collect trace when retrying the failed test. See https://playwright.dev/docs/trace-viewer */
    trace: 'on-first-retry',
    
    /* Take screenshot on failure */
    screenshot: 'only-on-failure',
    
    /* Record video on failure */
    video: 'retain-on-failure',
  },

  /* Visual regression testing settings */
  expect: {
    /* Threshold for visual differences (0-1) */
    toHaveScreenshot: { threshold: 0.2 },
    toMatchSnapshot: { threshold: 0.2 }
  },

  /* Configure projects for major browsers */
  projects: [
    {
      name: 'chromium',
      use: { 
        ...devices['Desktop Chrome'],
        // Enhanced browser-specific settings for E2E testing
        launchOptions: {
          args: ['--no-sandbox', '--disable-dev-shm-usage']
        }
      },
    },

    {
      name: 'firefox',
      use: { 
        ...devices['Desktop Firefox'],
        // Firefox-specific configurations for E2E testing
        launchOptions: {
          firefoxUserPrefs: {
            'media.navigator.streams.fake': true,
            'media.navigator.permission.disabled': true,
          }
        }
      },
    },

    {
      name: 'webkit',
      use: { 
        ...devices['Desktop Safari'],
        // Safari-specific configurations for E2E testing
      },
    },

    /* Enhanced mobile viewport testing */
    {
      name: 'Mobile Chrome',
      use: { 
        ...devices['Pixel 5'],
        // Mobile Chrome optimizations
        hasTouch: true,
        isMobile: true,
      },
    },
    {
      name: 'Mobile Safari',
      use: { 
        ...devices['iPhone 12'],
        // Mobile Safari optimizations
        hasTouch: true,
        isMobile: true,
      },
    },
    
    /* Additional mobile viewports for comprehensive testing */
    {
      name: 'Mobile Chrome Small',
      use: {
        ...devices['iPhone SE'],
        hasTouch: true,
        isMobile: true,
      },
    },
    {
      name: 'Tablet iPad',
      use: {
        ...devices['iPad Pro'],
        hasTouch: true,
        isMobile: false,
      },
    },

    /* Test against branded browsers for cross-browser validation */
    {
      name: 'Microsoft Edge',
      use: { 
        ...devices['Desktop Edge'], 
        channel: 'msedge',
        launchOptions: {
          args: ['--no-sandbox', '--disable-dev-shm-usage']
        }
      },
    },
    {
      name: 'Google Chrome',
      use: { 
        ...devices['Desktop Chrome'], 
        channel: 'chrome',
        launchOptions: {
          args: ['--no-sandbox', '--disable-dev-shm-usage']
        }
      },
    },
  ],

  /* Run your local dev server before starting the tests */
  webServer: {
    command: 'PORT=3001 npm run dev',
    url: 'http://localhost:3001',
    reuseExistingServer: true, // Use our existing server
    timeout: 120 * 1000,
    stderr: 'pipe',
    stdout: 'pipe',
  },
});