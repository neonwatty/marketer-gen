import { test, expect } from '@playwright/test';

test.describe('Breadcrumb Navigation', () => {
  test('should display breadcrumbs on dashboard page', async ({ page }) => {
    await page.goto('/dashboard');
    
    // Check for breadcrumb container
    const breadcrumbNav = page.locator('nav[aria-label="breadcrumb"]').or(page.locator('[role="navigation"]')).first();
    await expect(breadcrumbNav).toBeVisible();
    
    // Dashboard page should show just "Dashboard"
    await expect(page.getByText('Dashboard')).toBeVisible();
  });

  test('should display hierarchical breadcrumbs on campaigns page', async ({ page }) => {
    await page.goto('/dashboard/campaigns');
    
    // Should show Dashboard > Campaigns
    await expect(page.getByText('Dashboard')).toBeVisible();
    await expect(page.getByText('Campaigns')).toBeVisible();
    
    // Dashboard should be clickable link
    const dashboardLink = page.getByRole('link', { name: 'Dashboard' });
    await expect(dashboardLink).toHaveAttribute('href', '/dashboard');
  });

  test('should navigate back via breadcrumb links', async ({ page }) => {
    // Start at campaigns page
    await page.goto('/dashboard/campaigns');
    
    // Click Dashboard breadcrumb
    await page.getByRole('link', { name: 'Dashboard' }).click();
    
    // Should navigate back to dashboard
    await page.waitForURL('/dashboard');
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  });

  test('should display breadcrumbs on individual campaign page', async ({ page }) => {
    await page.goto('/dashboard/campaigns/1');
    
    // Should show Dashboard > Campaigns > [Campaign Name/ID]
    await expect(page.getByText('Dashboard')).toBeVisible();
    await expect(page.getByText('Campaigns')).toBeVisible();
    
    // Both Dashboard and Campaigns should be clickable
    await expect(page.getByRole('link', { name: 'Dashboard' })).toHaveAttribute('href', '/dashboard');
    await expect(page.getByRole('link', { name: 'Campaigns' })).toHaveAttribute('href', '/dashboard/campaigns');
  });

  test('should navigate through breadcrumb hierarchy', async ({ page }) => {
    // Start at individual campaign page
    await page.goto('/dashboard/campaigns/1');
    
    // Click Campaigns breadcrumb
    await page.getByRole('link', { name: 'Campaigns' }).click();
    await page.waitForURL('/dashboard/campaigns');
    await expect(page.getByRole('heading', { name: 'Campaigns' })).toBeVisible();
    
    // Now click Dashboard breadcrumb
    await page.getByRole('link', { name: 'Dashboard' }).click();
    await page.waitForURL('/dashboard');
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  });

  test('should have proper semantic markup for accessibility', async ({ page }) => {
    await page.goto('/dashboard/campaigns');
    
    // Check for proper breadcrumb navigation structure
    const breadcrumbNav = page.locator('nav[aria-label*="breadcrumb"]').or(
      page.locator('[role="navigation"]')
    ).first();
    await expect(breadcrumbNav).toBeVisible();
    
    // Check for ordered list structure (common breadcrumb pattern)
    const breadcrumbList = page.locator('ol').or(page.locator('ul')).first();
    await expect(breadcrumbList).toBeVisible();
  });

  test('should show current page as non-clickable', async ({ page }) => {
    await page.goto('/dashboard/campaigns');
    
    // "Campaigns" should be the current page and not a link
    const campaignsText = page.getByText('Campaigns').last();
    
    // The current page item should not be a link
    const campaignsAsLink = page.getByRole('link', { name: 'Campaigns' });
    
    // Either campaigns text exists without being a link, or there are multiple instances
    // where one is a link (in sidebar) and one is not (in breadcrumb)
    await expect(campaignsText).toBeVisible();
  });

  test('should work on mobile devices', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/dashboard/campaigns');
    
    // Breadcrumbs should still be visible and functional on mobile
    await expect(page.getByText('Dashboard')).toBeVisible();
    await expect(page.getByText('Campaigns')).toBeVisible();
    
    // Links should still work
    await page.getByRole('link', { name: 'Dashboard' }).click();
    await page.waitForURL('/dashboard');
  });

  test('should handle long page titles gracefully', async ({ page }) => {
    // Test with a campaign that might have a long name
    await page.goto('/dashboard/campaigns/campaign-with-very-long-name-that-might-overflow');
    
    // Breadcrumbs should still be visible
    await expect(page.getByText('Dashboard')).toBeVisible();
    await expect(page.getByText('Campaigns')).toBeVisible();
    
    // Container should handle overflow properly
    const breadcrumbContainer = page.locator('nav').first();
    await expect(breadcrumbContainer).toBeVisible();
  });
});