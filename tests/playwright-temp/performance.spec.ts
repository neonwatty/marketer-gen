import { test, expect } from '@playwright/test';

test.describe('Performance Testing', () => {
  test('should load dashboard page within performance budget', async ({ page }) => {
    const startTime = Date.now();
    
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');
    
    const loadTime = Date.now() - startTime;
    
    // Dashboard should load within 3 seconds
    expect(loadTime).toBeLessThan(3000);
    
    // Check that main content is visible
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  });

  test('should have good Core Web Vitals', async ({ page }) => {
    await page.goto('/dashboard');
    
    // Wait for page to fully load
    await page.waitForLoadState('networkidle');
    
    // Measure layout shift
    const layoutShift = await page.evaluate(() => {
      return new Promise((resolve) => {
        let cls = 0;
        const observer = new PerformanceObserver((list) => {
          for (const entry of list.getEntries()) {
            if (entry.entryType === 'layout-shift' && !entry.hadRecentInput) {
              cls += entry.value;
            }
          }
        });
        observer.observe({ entryTypes: ['layout-shift'] });
        
        setTimeout(() => {
          observer.disconnect();
          resolve(cls);
        }, 2000);
      });
    });
    
    // Cumulative Layout Shift should be less than 0.1 (good)
    expect(layoutShift).toBeLessThan(0.1);
  });

  test('should load resources efficiently', async ({ page }) => {
    // Track network requests
    const resourceSizes = [];
    const resourceTypes = {};
    
    page.on('response', async (response) => {
      const request = response.request();
      const resourceType = request.resourceType();
      const url = request.url();
      
      if (!resourceTypes[resourceType]) {
        resourceTypes[resourceType] = 0;
      }
      resourceTypes[resourceType]++;
      
      try {
        const body = await response.body();
        resourceSizes.push({
          url,
          type: resourceType,
          size: body.length
        });
      } catch (e) {
        // Some responses can't be read
      }
    });
    
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');
    
    // Check resource counts are reasonable
    expect(resourceTypes.stylesheet || 0).toBeLessThan(10); // CSS files
    expect(resourceTypes.script || 0).toBeLessThan(20); // JS files
    expect(resourceTypes.image || 0).toBeLessThan(15); // Images
    
    // Check for large resources
    const largeResources = resourceSizes.filter(resource => resource.size > 500000); // 500KB
    expect(largeResources.length).toBeLessThan(3);
  });

  test('should render above-the-fold content quickly', async ({ page }) => {
    const startTime = Date.now();
    
    await page.goto('/dashboard');
    
    // Wait for header to be visible (above-the-fold)
    await expect(page.locator('header')).toBeVisible();
    
    const headerRenderTime = Date.now() - startTime;
    
    // Header should render within 1 second
    expect(headerRenderTime).toBeLessThan(1000);
    
    // Wait for main heading (above-the-fold)
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
    
    const mainContentRenderTime = Date.now() - startTime;
    
    // Main content should render within 1.5 seconds
    expect(mainContentRenderTime).toBeLessThan(1500);
  });

  test('should handle navigation performance', async ({ page }) => {
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');
    
    // Measure navigation time to campaigns page
    const navStartTime = Date.now();
    
    await page.getByRole('link', { name: 'Campaigns' }).click();
    await page.waitForURL('/dashboard/campaigns');
    await expect(page.getByRole('heading', { name: 'Campaigns' })).toBeVisible();
    
    const navTime = Date.now() - navStartTime;
    
    // Client-side navigation should be fast (< 500ms)
    expect(navTime).toBeLessThan(500);
  });

  test('should optimize font loading', async ({ page }) => {
    const fontLoadPromises = [];
    
    page.on('response', async (response) => {
      const url = response.url();
      if (url.includes('font') || response.request().resourceType() === 'font') {
        fontLoadPromises.push(response.finished());
      }
    });
    
    await page.goto('/dashboard');
    
    // Wait for all fonts to load
    await Promise.all(fontLoadPromises);
    
    // Check that text is visible (not invisible due to font loading)
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
    
    // Verify text has proper font styling
    const heading = page.getByRole('heading', { name: 'Dashboard' });
    const fontFamily = await heading.evaluate(el => getComputedStyle(el).fontFamily);
    expect(fontFamily).toBeTruthy();
    expect(fontFamily).not.toBe('serif'); // Should use custom fonts
  });

  test('should minimize JavaScript bundle size', async ({ page }) => {
    const jsResources = [];
    
    page.on('response', async (response) => {
      const request = response.request();
      if (request.resourceType() === 'script') {
        try {
          const body = await response.body();
          jsResources.push({
            url: request.url(),
            size: body.length
          });
        } catch (e) {
          // Some scripts can't be read
        }
      }
    });
    
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');
    
    // Calculate total JS size
    const totalJsSize = jsResources.reduce((total, resource) => total + resource.size, 0);
    
    // Total JS should be reasonable (less than 1MB for dashboard)
    expect(totalJsSize).toBeLessThan(1024 * 1024); // 1MB
    
    // No single JS file should be excessively large
    const largestJs = Math.max(...jsResources.map(r => r.size));
    expect(largestJs).toBeLessThan(500 * 1024); // 500KB
  });

  test('should handle image loading efficiently', async ({ page }) => {
    const imageResources = [];
    
    page.on('response', async (response) => {
      const request = response.request();
      if (request.resourceType() === 'image') {
        try {
          const body = await response.body();
          imageResources.push({
            url: request.url(),
            size: body.length
          });
        } catch (e) {
          // Some images can't be read
        }
      }
    });
    
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');
    
    // Images should be optimized
    imageResources.forEach(image => {
      expect(image.size).toBeLessThan(200 * 1024); // 200KB per image
    });
    
    // Check that images have proper loading attributes
    const images = page.locator('img');
    const imageCount = await images.count();
    
    if (imageCount > 0) {
      for (let i = 0; i < imageCount; i++) {
        const img = images.nth(i);
        const loading = await img.getAttribute('loading');
        // Images should use lazy loading when appropriate
        if (loading) {
          expect(['lazy', 'eager']).toContain(loading);
        }
      }
    }
  });

  test('should have good runtime performance', async ({ page }) => {
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');
    
    // Measure runtime performance during interactions
    const startTime = Date.now();
    
    // Perform some interactions
    await page.getByRole('link', { name: 'Campaigns' }).hover();
    await page.getByRole('button', { name: 'Account Settings' }).hover();
    
    // Open user menu
    const userMenuTrigger = page.locator('[role="button"]').filter({ has: page.locator('[role="img"]') }).last();
    await userMenuTrigger.click();
    await userMenuTrigger.click(); // Close it
    
    const interactionTime = Date.now() - startTime;
    
    // Interactions should be responsive (< 100ms)
    expect(interactionTime).toBeLessThan(100);
  });

  test('should handle mobile performance', async ({ page }) => {
    // Simulate mobile device
    await page.setViewportSize({ width: 375, height: 667 });
    
    const startTime = Date.now();
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');
    
    const loadTime = Date.now() - startTime;
    
    // Mobile should load within 4 seconds (allowing for slower mobile networks)
    expect(loadTime).toBeLessThan(4000);
    
    // Check that mobile interactions are responsive
    const mobileInteractionStart = Date.now();
    
    const sidebarTrigger = page.locator('button').first();
    if (await sidebarTrigger.isVisible()) {
      await sidebarTrigger.click();
    }
    
    const mobileInteractionTime = Date.now() - mobileInteractionStart;
    expect(mobileInteractionTime).toBeLessThan(200);
  });

  test('should not have memory leaks during navigation', async ({ page }) => {
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');
    
    // Navigate between pages multiple times
    for (let i = 0; i < 5; i++) {
      await page.getByRole('link', { name: 'Campaigns' }).click();
      await page.waitForURL('/dashboard/campaigns');
      
      await page.getByRole('link', { name: 'Dashboard' }).click();
      await page.waitForURL('/dashboard');
    }
    
    // Check that page is still responsive
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
    
    // Measure if we can still interact normally
    const userMenuTrigger = page.locator('[role="button"]').filter({ has: page.locator('[role="img"]') }).last();
    await userMenuTrigger.click();
    await expect(page.getByText('Demo User')).toBeVisible();
  });
});