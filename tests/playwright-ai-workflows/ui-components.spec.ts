import { test, expect } from '@playwright/test';

test.describe('UI Components Integration', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/dashboard');
  });

  test.describe('Basic Smoke Tests', () => {
    test('should load dashboard page successfully', async ({ page }) => {
      // Just check that the page loads without major errors
      await expect(page.locator('body')).toBeVisible();
      
      // Check that we have basic HTML structure
      await expect(page.locator('html')).toBeVisible();
      
      // Verify the page has loaded by checking for any text content
      const pageText = await page.textContent('body');
      expect(pageText).toBeTruthy();
      expect(pageText!.length).toBeGreaterThan(0);
    });

    test('should have no JavaScript errors', async ({ page }) => {
      const errors: string[] = [];
      
      page.on('pageerror', (error) => {
        errors.push(error.message);
      });

      page.on('console', (msg) => {
        if (msg.type() === 'error') {
          errors.push(msg.text());
        }
      });

      // Wait a bit to catch any errors
      await page.waitForTimeout(2000);
      
      // Filter out known warnings and resource loading issues that aren't critical errors
      const actualErrors = errors.filter(error => 
        !error.includes('Warning:') && 
        !error.includes('ReactDOM.render') &&
        !error.includes('useLayoutEffect') &&
        !error.includes('Failed to load resource') &&
        !error.includes('404 (Not Found)') &&
        !error.includes('favicon.ico')
      );
      
      expect(actualErrors).toHaveLength(0);
    });

    test('should be responsive', async ({ page }) => {
      // Test different viewport sizes
      const viewports = [
        { width: 1920, height: 1080 }, // Desktop
        { width: 768, height: 1024 },  // Tablet
        { width: 375, height: 667 }    // Mobile
      ];

      for (const viewport of viewports) {
        await page.setViewportSize(viewport);
        
        // Just check that the page still loads and has content
        await expect(page.locator('body')).toBeVisible();
        const pageText = await page.textContent('body');
        expect(pageText).toBeTruthy();
        expect(pageText!.length).toBeGreaterThan(0);
      }
    });

    test('should have basic interactivity', async ({ page }) => {
      // Look for any clickable elements (buttons, links)
      const buttons = page.locator('button');
      const links = page.locator('a');
      
      const buttonCount = await buttons.count();
      const linkCount = await links.count();
      
      // We should have some interactive elements
      expect(buttonCount + linkCount).toBeGreaterThan(0);
      
      // Try clicking the first button if it exists
      if (buttonCount > 0) {
        const firstButton = buttons.first();
        if (await firstButton.isVisible() && await firstButton.isEnabled()) {
          await firstButton.click();
          // Just check that clicking doesn't crash the page
          await expect(page.locator('body')).toBeVisible();
        }
      }
    });
  });
});