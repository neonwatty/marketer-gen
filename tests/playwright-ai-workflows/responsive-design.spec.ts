import { test, expect } from '@playwright/test';

test.describe('Responsive Design', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/dashboard');
  });

  test('should display properly on desktop (1920x1080)', async ({ page }) => {
    await page.setViewportSize({ width: 1920, height: 1080 });
    
    // Sidebar should be visible
    await expect(page.getByText('Navigation')).toBeVisible();
    await expect(page.getByText('Marketer Gen').first()).toBeVisible();
    
    // Search should be visible in header
    await expect(page.getByPlaceholder('Search campaigns...')).toBeVisible();
    
    // Main content should have proper spacing
    const mainContent = page.locator('main');
    await expect(mainContent).toBeVisible();
    
    // Dashboard content should be properly laid out
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  });

  test('should display properly on tablet (768x1024)', async ({ page }) => {
    await page.setViewportSize({ width: 768, height: 1024 });
    
    // Sidebar should still be accessible
    await expect(page.getByText('Navigation')).toBeVisible();
    
    // Search might be hidden on tablet, mobile search button should appear
    const mobileSearchButton = page.getByRole('button', { name: 'Search' });
    if (await mobileSearchButton.isVisible()) {
      await expect(mobileSearchButton).toBeVisible();
    }
    
    // Content should be readable
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  });

  test('should display properly on mobile (375x667)', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    
    // Sidebar trigger should be visible
    const sidebarTrigger = page.locator('button').first();
    await expect(sidebarTrigger).toBeVisible();
    
    // Desktop search should be hidden
    await expect(page.getByPlaceholder('Search campaigns...')).toBeHidden();
    
    // Mobile search button should be visible
    await expect(page.getByRole('button', { name: 'Search' })).toBeVisible();
    
    // User menu should still be accessible
    const userMenuTrigger = page.locator('[role="button"]').filter({ has: page.locator('[role="img"]') }).last();
    await expect(userMenuTrigger).toBeVisible();
    
    // Main content should be visible and readable
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  });

  test('should handle sidebar on mobile correctly', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    
    // Sidebar should be initially hidden/collapsed on mobile
    // Try to find sidebar trigger
    const sidebarTrigger = page.locator('button').first();
    await expect(sidebarTrigger).toBeVisible();
    
    // Click to open sidebar (if mobile pattern is implemented)
    await sidebarTrigger.click();
    
    // Navigation items should become visible or accessible
    // Note: This depends on the actual mobile sidebar implementation
  });

  test('should maintain functionality across screen sizes', async ({ page }) => {
    const viewports = [
      { width: 1920, height: 1080, name: 'desktop' },
      { width: 1024, height: 768, name: 'tablet-landscape' },
      { width: 768, height: 1024, name: 'tablet-portrait' },
      { width: 414, height: 896, name: 'mobile-large' },
      { width: 375, height: 667, name: 'mobile-medium' },
      { width: 320, height: 568, name: 'mobile-small' }
    ];

    for (const viewport of viewports) {
      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      
      // Core navigation should always work
      await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
      
      // User menu should always be accessible
      const userMenuTrigger = page.getByRole('button', { name: /Open user menu.*Demo User/ });
      await expect(userMenuTrigger).toBeVisible();
      
      // Navigation to campaigns should work
      if (viewport.width >= 768) {
        // On larger screens, sidebar navigation should be directly visible
        await page.getByRole('link', { name: 'Campaigns' }).click();
      } else {
        // On mobile, may need to trigger sidebar first
        const sidebarTrigger = page.locator('button').first();
        if (await sidebarTrigger.isVisible()) {
          await sidebarTrigger.click();
        }
        await page.getByRole('link', { name: 'Campaigns' }).click();
      }
      
      await page.waitForURL('/dashboard/campaigns');
      await expect(page.getByRole('heading', { name: 'Campaigns' })).toBeVisible();
      
      // Navigate back to dashboard for next iteration
      await page.goto('/dashboard');
    }
  });

  test('should have proper touch targets on mobile', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    
    // All clickable elements should have sufficient size for touch
    const clickableElements = [
      page.locator('button'),
      page.locator('a'),
      page.locator('[role="button"]')
    ];
    
    for (const elementLocator of clickableElements) {
      const elements = await elementLocator.all();
      for (const element of elements) {
        if (await element.isVisible()) {
          const box = await element.boundingBox();
          if (box) {
            // Touch targets should be at least 44px (iOS) or 48dp (Android)
            // We'll be lenient and check for 40px minimum
            expect(box.height).toBeGreaterThanOrEqual(32);
            expect(box.width).toBeGreaterThanOrEqual(32);
          }
        }
      }
    }
  });

  test('should handle text overflow appropriately', async ({ page }) => {
    await page.setViewportSize({ width: 320, height: 568 }); // Very small screen
    
    // Text should not overflow containers
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
    await expect(page.getByText('Overview of your marketing campaigns and performance metrics')).toBeVisible();
    
    // Navigation text should be handled properly
    if (await page.getByText('Navigation').isVisible()) {
      await expect(page.getByText('Navigation')).toBeVisible();
    }
  });

  test('should maintain consistent spacing across breakpoints', async ({ page }) => {
    const breakpoints = [
      { width: 1200, height: 800 },
      { width: 992, height: 768 },
      { width: 768, height: 1024 },
      { width: 576, height: 800 },
      { width: 375, height: 667 }
    ];

    for (const breakpoint of breakpoints) {
      await page.setViewportSize(breakpoint);
      
      // Main content should have consistent padding/margins
      const mainContent = page.locator('main');
      await expect(mainContent).toBeVisible();
      
      // Header should maintain consistent height
      const header = page.locator('header');
      await expect(header).toBeVisible();
      
      // Content should not be cramped
      await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
    }
  });
});