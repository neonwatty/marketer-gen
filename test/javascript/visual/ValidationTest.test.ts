import { test, expect } from '@playwright/test';

// Simple validation test to demonstrate cross-browser testing setup
test.describe('Cross-Browser Setup Validation', () => {
  test('basic browser functionality test', async ({ page, browserName }) => {
    console.log(`Testing on ${browserName}`);
    
    // Test basic page navigation
    await page.goto('https://example.com');
    
    // Verify page loads
    await expect(page).toHaveTitle(/Example Domain/);
    
    // Test basic CSS and layout
    const heading = page.locator('h1');
    await expect(heading).toBeVisible();
    
    // Take a screenshot to verify rendering
    await expect(page).toHaveScreenshot(`validation-${browserName}.png`);
    
    console.log(`✅ ${browserName} browser test passed`);
  });
  
  test('viewport responsiveness test', async ({ page, browserName }) => {
    await page.goto('https://example.com');
    
    // Test different viewport sizes
    const viewports = [
      { width: 320, height: 568, name: 'mobile' },
      { width: 768, height: 1024, name: 'tablet' },
      { width: 1920, height: 1080, name: 'desktop' }
    ];
    
    for (const viewport of viewports) {
      await page.setViewportSize(viewport);
      await page.waitForTimeout(500); // Allow layout to settle
      
      await expect(page).toHaveScreenshot(`responsive-${viewport.name}-${browserName}.png`);
      console.log(`✅ ${browserName} ${viewport.name} viewport test passed`);
    }
  });
});