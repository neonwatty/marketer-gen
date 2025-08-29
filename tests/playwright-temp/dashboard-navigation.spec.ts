import { test, expect } from '@playwright/test';

test.describe('Dashboard Navigation', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/dashboard');
  });

  test('should display main dashboard page with correct layout', async ({ page }) => {
    // Check for dashboard header
    await expect(page.locator('header')).toBeVisible();
    await expect(page.getByText('Marketer Gen')).toBeVisible();
    
    // Check for sidebar navigation
    await expect(page.getByText('Navigation')).toBeVisible();
    await expect(page.getByText('Overview')).toBeVisible();
    await expect(page.getByText('Campaigns')).toBeVisible();
    await expect(page.getByText('Analytics')).toBeVisible();
    await expect(page.getByText('Audience')).toBeVisible();
    await expect(page.getByText('Templates')).toBeVisible();
    await expect(page.getByText('Settings')).toBeVisible();
    
    // Check main content area - use text content approach
    const pageText = await page.textContent('body');
    expect(pageText).toContain('Dashboard');
    expect(pageText).toContain('Overview of your marketing campaigns');
    expect(pageText).toContain('Dashboard components will be added');
  });

  test('should navigate to campaigns page via sidebar', async ({ page }) => {
    // Click on Campaigns in sidebar
    await page.getByRole('link', { name: 'Campaigns' }).click();
    
    // Wait for navigation
    await page.waitForURL('/dashboard/campaigns');
    
    // Check campaigns page content
    const pageText = await page.textContent('body');
    expect(pageText).toContain('Campaigns');
    
    // Check breadcrumb navigation
    await expect(page.getByText('Dashboard')).toBeVisible();
    await expect(page.getByText('Campaigns')).toBeVisible();
    
    // Check for campaigns placeholder
    await expect(page.getByText('Campaign listing and management components will be added in task 4.3')).toBeVisible();
  });

  test('should navigate to individual campaign page', async ({ page }) => {
    // Navigate to campaigns first
    await page.getByRole('link', { name: 'Campaigns' }).click();
    await page.waitForURL('/dashboard/campaigns');
    
    // Navigate to individual campaign (test with ID 1)
    await page.goto('/dashboard/campaigns/1');
    
    // Check for campaign detail page structure
    await expect(page.locator('h1')).toBeVisible();
    
    // Should have breadcrumb navigation including campaign ID
    await expect(page.getByText('Dashboard')).toBeVisible();
    await expect(page.getByText('Campaigns')).toBeVisible();
  });

  test('should show quick actions in sidebar', async ({ page }) => {
    // Check for Quick Actions section
    await expect(page.getByText('Quick Actions')).toBeVisible();
    await expect(page.getByRole('link', { name: 'New Campaign' })).toBeVisible();
    
    // Click New Campaign link
    await page.getByRole('link', { name: 'New Campaign' }).click();
    
    // Should navigate to campaign creation page
    await page.waitForURL('/dashboard/campaigns/new');
  });

  test('should highlight active navigation item', async ({ page }) => {
    // Check that Overview is active on dashboard page
    const overviewLink = page.getByRole('link', { name: 'Overview' });
    await expect(overviewLink).toHaveAttribute('aria-current', 'page');
    
    // Navigate to campaigns and check active state
    await page.getByRole('link', { name: 'Campaigns' }).click();
    await page.waitForURL('/dashboard/campaigns');
    
    const campaignsLink = page.getByRole('link', { name: 'Campaigns' });
    await expect(campaignsLink).toHaveAttribute('aria-current', 'page');
  });

  test('should have responsive design for mobile', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    
    // Sidebar should be collapsed on mobile
    const sidebarTrigger = page.locator('[data-testid="sidebar-trigger"]').or(page.getByRole('button', { name: 'Toggle navigation' }));
    await expect(sidebarTrigger).toBeVisible();
    
    // Main content should be visible
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  });
});