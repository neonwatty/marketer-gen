// playwright.config.js - Optimized for AI Workflow Testing
const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  // Test directory
  testDir: './tests',
  
  // Global timeout - increased for AI processing
  timeout: 300000, // 5 minutes for AI operations
  
  // Run tests in fully parallel with reduced workers for AI stability
  fullyParallel: true,
  
  // Fail the build on CI if you accidentally left test.only in the source code
  forbidOnly: !!process.env.CI,
  
  // Retry for stability (increased for flaky auth)
  retries: process.env.CI ? 2 : 1,
  
  // Reduced workers for AI workflows stability (single worker for auth reliability)
  workers: 1,
  
  // Reporter configuration - fixed folder conflict
  reporter: [
    ['html', { outputFolder: 'playwright-reports/html-report' }],
    ['json', { outputFile: 'playwright-reports/results.json' }],
    ['junit', { outputFile: 'playwright-reports/results.xml' }]
  ],
  
  // Shared settings for all the projects
  use: {
    // Base URL for the Rails app
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    
    // Global test timeout - increased for AI operations
    actionTimeout: 90000, // 1.5 minutes
    navigationTimeout: 90000, // 1.5 minutes
    
    // Take screenshot on failure
    screenshot: 'only-on-failure',
    
    // Record video on failure
    video: 'retain-on-failure',
    
    // Trace on failure for debugging
    trace: 'retain-on-failure',
  },

  // Expect timeout for assertions
  expect: {
    timeout: 30000
  },

  // Configure projects for AI workflow testing
  projects: [
    // Primary AI Workflows - Desktop Chrome (most stable for AI testing)
    {
      name: 'ai-workflows',
      testDir: './tests/ai-workflows',
      use: { 
        ...devices['Desktop Chrome'],
        // Extended timeouts for AI processing
        actionTimeout: 90000,
        navigationTimeout: 90000,
      },
    },

    // Cross-browser testing (optional - can be enabled for comprehensive testing)
    // {
    //   name: 'firefox-ai',
    //   testDir: './tests/ai-workflows',
    //   use: { 
    //     ...devices['Desktop Firefox'],
    //     actionTimeout: 90000,
    //   },
    // },
    
    // Mobile testing for responsive AI interfaces
    // {
    //   name: 'mobile-ai',
    //   testDir: './tests/ai-workflows',
    //   use: { 
    //     ...devices['Pixel 5'],
    //     actionTimeout: 120000, // Even longer for mobile
    //   },
    // },
  ],

  // Web server configuration for Rails
  webServer: {
    command: 'USE_REAL_LLM=false LLM_ENABLED=true rails server -e test -p 3000',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120000,
    env: {
      RAILS_ENV: 'test',
      LLM_ENABLED: 'true',
      USE_REAL_LLM: 'false', // Force mock in tests
      LLM_REQUEST_TIMEOUT: '30',
      LLM_MAX_RETRIES: '2',
      DEFAULT_LLM_PROVIDER: 'mock'
    }
  },
});