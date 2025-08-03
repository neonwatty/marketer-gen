import { test, expect, Page, BrowserContext, devices } from '@playwright/test';

// Comprehensive Cross-Browser and Device Compatibility Tests
test.describe('Cross-Browser Compatibility Test Suite', () => {
  
  // Performance testing across browsers
  test.describe('Performance Testing', () => {
    test('dashboard load performance across browsers', async ({ page, browserName }) => {
      // Start performance monitoring
      await page.goto('/dashboard', { waitUntil: 'networkidle' });
      
      // Measure Core Web Vitals
      const metrics = await page.evaluate(() => {
        return new Promise((resolve) => {
          new PerformanceObserver((list) => {
            const entries = list.getEntries();
            const vitals = {};
            
            entries.forEach((entry) => {
              if (entry.name === 'FCP') vitals['FCP'] = entry.value;
              if (entry.name === 'LCP') vitals['LCP'] = entry.value;
              if (entry.name === 'FID') vitals['FID'] = entry.value;
              if (entry.name === 'CLS') vitals['CLS'] = entry.value;
            });
            
            resolve(vitals);
          }).observe({ entryTypes: ['measure', 'navigation', 'paint'] });
          
          // Fallback timeout
          setTimeout(() => resolve({}), 5000);
        });
      });
      
      console.log(`${browserName} performance metrics:`, metrics);
      
      // Take screenshot after load
      await expect(page.locator('[data-testid="dashboard-widgets"]')).toHaveScreenshot(
        `performance-dashboard-${browserName}.png`
      );
    });
    
    test('content editor rendering performance', async ({ page, browserName }) => {
      const startTime = Date.now();
      
      await page.goto('/content/new');
      await page.waitForSelector('[data-testid="rich-text-editor"]', { state: 'visible' });
      
      const loadTime = Date.now() - startTime;
      console.log(`${browserName} content editor load time: ${loadTime}ms`);
      
      // Should load within reasonable time
      expect(loadTime).toBeLessThan(3000);
      
      // Test text input responsiveness
      const editor = page.locator('[data-testid="rich-text-editor"] [contenteditable]');
      const inputStart = Date.now();
      
      await editor.type('Performance test content');
      const inputTime = Date.now() - inputStart;
      
      console.log(`${browserName} text input response time: ${inputTime}ms`);
      expect(inputTime).toBeLessThan(1000);
    });
  });
  
  // Touch interaction testing
  test.describe('Touch Interactions', () => {
    test('touch gestures on mobile devices', async ({ page, browserName }) => {
      // Skip if not mobile device
      const isMobile = await page.evaluate(() => 'ontouchstart' in window);
      if (!isMobile) {
        test.skip();
      }
      
      await page.goto('/dashboard');
      await page.waitForSelector('[data-testid="dashboard-widgets"]');
      
      // Test touch scroll
      const dashboardElement = page.locator('[data-testid="dashboard-widgets"]');
      const box = await dashboardElement.boundingBox();
      
      if (box) {
        // Swipe down gesture
        await page.touchscreen.tap(box.x + box.width / 2, box.y + 100);
        await page.touchscreen.swipe(
          box.x + box.width / 2, box.y + 100,
          box.x + box.width / 2, box.y + 300,
          500 // duration in ms
        );
        
        await page.waitForTimeout(500);
        await expect(dashboardElement).toHaveScreenshot(`touch-scroll-${browserName}.png`);
      }
    });
    
    test('swipe gestures in campaign table', async ({ page, browserName }) => {
      const viewport = page.viewportSize();
      if (!viewport || viewport.width > 768) {
        test.skip(); // Only test on mobile/tablet
      }
      
      await page.goto('/campaigns');
      await page.waitForSelector('[data-testid="campaign-table"]');
      
      const table = page.locator('[data-testid="campaign-table"]');
      const box = await table.boundingBox();
      
      if (box) {
        // Test horizontal swipe for mobile table scrolling
        await page.touchscreen.swipe(
          box.x + box.width - 50, box.y + box.height / 2,
          box.x + 50, box.y + box.height / 2,
          300
        );
        
        await page.waitForTimeout(500);
        await expect(table).toHaveScreenshot(`mobile-table-swipe-${browserName}.png`);
      }
    });
    
    test('pinch-to-zoom on charts', async ({ page, browserName }) => {
      await page.goto('/analytics');
      await page.waitForSelector('[data-testid="line-chart"]');
      
      const chart = page.locator('[data-testid="line-chart"]');
      const box = await chart.boundingBox();
      
      if (box) {
        // Simulate pinch gesture
        await page.touchscreen.tap(box.x + box.width / 2 - 50, box.y + box.height / 2);
        await page.touchscreen.tap(box.x + box.width / 2 + 50, box.y + box.height / 2);
        
        // Pinch out (zoom in)
        await page.touchscreen.swipe(
          box.x + box.width / 2 - 50, box.y + box.height / 2,
          box.x + box.width / 2 - 100, box.y + box.height / 2,
          500
        );
        
        await page.waitForTimeout(500);
        await expect(chart).toHaveScreenshot(`chart-pinch-zoom-${browserName}.png`);
      }
    });
  });
  
  // Browser-specific feature testing
  test.describe('Browser-Specific Features', () => {
    test('CSS Grid support verification', async ({ page, browserName }) => {
      await page.goto('/dashboard');
      
      // Check CSS Grid support
      const gridSupport = await page.evaluate(() => {
        return CSS.supports('display', 'grid');
      });
      
      console.log(`${browserName} CSS Grid support: ${gridSupport}`);
      
      if (gridSupport) {
        await expect(page.locator('[data-testid="dashboard-widgets"]')).toHaveScreenshot(
          `grid-layout-${browserName}.png`
        );
      }
    });
    
    test('Flexbox fallback verification', async ({ page, browserName }) => {
      await page.goto('/campaigns');
      
      // Check Flexbox support
      const flexSupport = await page.evaluate(() => {
        return CSS.supports('display', 'flex');
      });
      
      console.log(`${browserName} Flexbox support: ${flexSupport}`);
      
      await expect(page.locator('[data-testid="campaign-filters"]')).toHaveScreenshot(
        `flex-layout-${browserName}.png`
      );
    });
    
    test('WebP image format support', async ({ page, browserName }) => {
      // Test WebP support
      const webpSupport = await page.evaluate(() => {
        const canvas = document.createElement('canvas');
        return canvas.toDataURL('image/webp').indexOf('image/webp') === 5;
      });
      
      console.log(`${browserName} WebP support: ${webpSupport}`);
      
      if (webpSupport) {
        // Load page with WebP images
        await page.goto('/content/media');
        await page.waitForSelector('[data-testid="media-manager"]');
        
        await expect(page.locator('[data-testid="media-manager"]')).toHaveScreenshot(
          `webp-images-${browserName}.png`
        );
      }
    });
  });
  
  // Form behavior across browsers
  test.describe('Form Compatibility', () => {
    test('HTML5 input types across browsers', async ({ page, browserName }) => {
      await page.goto('/campaigns/new');
      
      const form = page.locator('[data-testid="campaign-form"]');
      await form.waitFor({ state: 'visible' });
      
      // Test different input types
      const inputTypes = ['email', 'tel', 'url', 'date', 'number', 'range'];
      
      for (const inputType of inputTypes) {
        const input = form.locator(`input[type="${inputType}"]`);
        if (await input.count() > 0) {
          await expect(input.first()).toHaveScreenshot(`input-${inputType}-${browserName}.png`);
        }
      }
    });
    
    test('form validation styling consistency', async ({ page, browserName }) => {
      await page.goto('/campaigns/new');
      
      const form = page.locator('[data-testid="campaign-form"]');
      await form.waitFor({ state: 'visible' });
      
      // Trigger validation errors
      await page.click('[data-testid="submit-campaign"]');
      await page.waitForTimeout(500);
      
      // Check validation styling
      const errorInputs = form.locator('.error, [aria-invalid="true"], :invalid');
      const count = await errorInputs.count();
      
      if (count > 0) {
        await expect(form).toHaveScreenshot(`form-validation-${browserName}.png`);
      }
    });
  });
  
  // Animation and transition testing
  test.describe('Animations and Transitions', () => {
    test('CSS animations across browsers', async ({ page, browserName }) => {
      await page.goto('/dashboard');
      
      // Test loading animations
      await page.reload();
      await page.waitForTimeout(100); // Catch loading state
      
      const loadingElements = page.locator('[data-testid*="loading"], .animate-pulse, .animate-spin');
      const count = await loadingElements.count();
      
      if (count > 0) {
        await expect(loadingElements.first()).toHaveScreenshot(`loading-animation-${browserName}.png`);
      }
    });
    
    test('hover effects consistency', async ({ page, browserName }) => {
      await page.goto('/campaigns');
      
      const button = page.locator('[data-testid="create-campaign"]').first();
      
      // Normal state
      await expect(button).toHaveScreenshot(`button-normal-${browserName}.png`);
      
      // Hover state
      await button.hover();
      await page.waitForTimeout(200); // Allow transition
      await expect(button).toHaveScreenshot(`button-hover-${browserName}.png`);
    });
    
    test('modal transitions', async ({ page, browserName }) => {
      await page.goto('/campaigns');
      
      // Open modal
      await page.click('[data-testid="open-modal"]');
      await page.waitForTimeout(300); // Allow animation
      
      const modal = page.locator('[data-testid="modal"]');
      if (await modal.count() > 0) {
        await expect(modal).toHaveScreenshot(`modal-open-${browserName}.png`);
      }
    });
  });
  
  // JavaScript API compatibility
  test.describe('JavaScript API Compatibility', () => {
    test('Fetch API support and fallback', async ({ page, browserName }) => {
      await page.goto('/dashboard');
      
      // Test Fetch API availability
      const fetchSupport = await page.evaluate(() => {
        return typeof fetch !== 'undefined';
      });
      
      console.log(`${browserName} Fetch API support: ${fetchSupport}`);
      
      // Make an API call and verify response handling
      await page.route('/api/dashboard/metrics', route => {
        route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ test: 'data' })
        });
      });
      
      // Trigger API call
      await page.reload();
      await page.waitForTimeout(1000);
      
      await expect(page.locator('[data-testid="dashboard-widgets"]')).toHaveScreenshot(
        `api-response-${browserName}.png`
      );
    });
    
    test('LocalStorage and SessionStorage support', async ({ page, browserName }) => {
      await page.goto('/settings/theme');
      
      // Test storage APIs
      const storageSupport = await page.evaluate(() => {
        try {
          localStorage.setItem('test', 'value');
          sessionStorage.setItem('test', 'value');
          return {
            localStorage: localStorage.getItem('test') === 'value',
            sessionStorage: sessionStorage.getItem('test') === 'value'
          };
        } catch (e) {
          return { localStorage: false, sessionStorage: false };
        }
      });
      
      console.log(`${browserName} Storage support:`, storageSupport);
      
      // Test theme persistence
      await page.click('[data-testid="dark-theme"]');
      await page.waitForTimeout(500);
      
      await page.reload();
      await page.waitForTimeout(500);
      
      await expect(page.locator('[data-testid="theme-customizer"]')).toHaveScreenshot(
        `theme-persistence-${browserName}.png`
      );
    });
  });
  
  // Accessibility across browsers
  test.describe('Accessibility Compatibility', () => {
    test('screen reader compatibility', async ({ page, browserName }) => {
      await page.goto('/dashboard');
      
      // Check ARIA attributes
      const ariaElements = await page.locator('[aria-label], [aria-describedby], [role]').count();
      console.log(`${browserName} ARIA elements found: ${ariaElements}`);
      
      // Test focus navigation
      await page.keyboard.press('Tab');
      const focusedElement = page.locator(':focus');
      
      if (await focusedElement.count() > 0) {
        await expect(focusedElement).toHaveScreenshot(`focus-ring-${browserName}.png`);
      }
    });
    
    test('high contrast mode support', async ({ page, browserName }) => {
      // Only test on browsers that support forced colors
      if (browserName === 'webkit') {
        test.skip(); // Safari doesn't support forced-colors
      }
      
      await page.emulateMedia({ forcedColors: 'active' });
      await page.goto('/dashboard');
      
      await expect(page.locator('[data-testid="dashboard-widgets"]')).toHaveScreenshot(
        `high-contrast-${browserName}.png`
      );
    });
  });
});

// Additional device-specific tests
test.describe('Device-Specific Testing', () => {
  const testDevices = [
    { name: 'iPhone 13', device: 'iPhone 13' },
    { name: 'iPad Pro', device: 'iPad Pro' },
    { name: 'Galaxy S21', device: 'Galaxy S21' },
    { name: 'Pixel 5', device: 'Pixel 5' }
  ];
  
  testDevices.forEach(({ name, device }) => {
    test(`${name} device compatibility`, async ({ browser }) => {
      const context = await browser.newContext({
        ...devices[device]
      });
      
      const page = await context.newPage();
      
      await page.goto('/dashboard');
      await page.waitForSelector('[data-testid="dashboard-widgets"]');
      
      // Test device-specific interactions
      if (name.includes('iPhone') || name.includes('Galaxy') || name.includes('Pixel')) {
        // Mobile-specific tests
        await page.touchscreen.tap(100, 100);
        await expect(page).toHaveScreenshot(`mobile-interaction-${name.replace(/\s+/g, '-')}.png`);
      } else {
        // Tablet-specific tests
        await expect(page).toHaveScreenshot(`tablet-layout-${name.replace(/\s+/g, '-')}.png`);
      }
      
      await context.close();
    });
  });
});