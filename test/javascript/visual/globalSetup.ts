import { chromium, FullConfig } from '@playwright/test';

async function globalSetup(config: FullConfig) {
  console.log('🚀 Starting Cross-Browser Visual Regression Test Suite');
  console.log('📋 Test Configuration:');
  console.log('   - Browsers: Chrome, Firefox, Safari, Edge');
  console.log('   - Devices: Desktop, Tablet, Mobile');
  console.log('   - Viewports: 320px to 2560px');
  console.log('   - Themes: Light, Dark, High Contrast');
  console.log('   - Accessibility: WCAG 2.1 AA compliance');
  
  // Set test environment variables
  process.env.TZ = 'UTC';
  process.env.NODE_ENV = 'test';
  
  // Initialize global test state
  global.testStartTime = Date.now();
  
  // Check if Rails server is running
  try {
    const browser = await chromium.launch();
    const page = await browser.newPage();
    
    // Test if the Rails application is accessible
    await page.goto('http://localhost:3000', { waitUntil: 'networkidle' });
    console.log('✅ Rails application server is accessible');
    
    await browser.close();
  } catch (error) {
    console.warn('⚠️  Rails server may not be running. Some tests might fail.');
    console.warn('   Please ensure Rails server is running on port 3000');
  }
  
  console.log('🎬 Starting visual regression tests...\n');
}

export default globalSetup;