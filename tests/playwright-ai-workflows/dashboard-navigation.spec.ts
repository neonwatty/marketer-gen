import { test, expect } from '@playwright/test';

test.describe('Dashboard Navigation', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/dashboard');
  });

  test('should display main dashboard page with correct layout', async ({ page }) => {
    // Check for dashboard header
    await expect(page.locator('header')).toBeVisible();
    await expect(page.locator('.text-sm.font-semibold').filter({ hasText: 'Marketer Gen' })).toBeVisible();
    
    // Check for sidebar navigation
    await expect(page.getByText('Navigation')).toBeVisible();
    await expect(page.getByRole('link', { name: 'Overview' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Campaigns' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Analytics' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Audience' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Templates' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Settings' })).toBeVisible();
    
    // Check main content area - use text content approach
    const pageText = await page.textContent('body');
    expect(pageText).toContain('Dashboard');
    expect(pageText).toContain('Overview of your marketing campaigns');
    expect(pageText).toContain('Dashboard components will be added');
  });

  test('should navigate to campaigns page via sidebar', async ({ page }) => {
    // Click on Campaigns in sidebar
    await page.getByRole('link', { name: 'Campaigns' }).first().click();
    
    // Wait for navigation
    await page.waitForURL('/dashboard/campaigns');
    
    // Check campaigns page content
    await expect(page.getByRole('heading', { name: 'Campaigns' })).toBeVisible();
    await expect(page.getByText('Manage and monitor your marketing campaigns')).toBeVisible();
    
    // Check breadcrumb navigation
    const breadcrumbNav = page.locator('nav[aria-label*="breadcrumb"]').first();
    await expect(breadcrumbNav.getByText('Dashboard')).toBeVisible();
    await expect(breadcrumbNav.getByText('Campaigns')).toBeVisible();
    
    // Check for Create Campaign button
    await expect(page.getByRole('link', { name: 'Create Campaign' })).toBeVisible();
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
    await expect(page.locator('nav').getByText('Dashboard')).toBeVisible();
    await expect(page.locator('nav').getByText('Campaigns')).toBeVisible();
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
    const overviewLink = page.locator('[data-sidebar="menu-button"]').filter({ hasText: 'Overview' }).first();
    await expect(overviewLink).toHaveAttribute('data-active', 'true');
    
    // Navigate to campaigns and check active state
    await page.getByRole('link', { name: 'Campaigns' }).first().click();
    await page.waitForURL('/dashboard/campaigns');
    
    const campaignsLink = page.locator('[data-sidebar="menu-button"]').filter({ hasText: 'Campaigns' }).first();
    await expect(campaignsLink).toHaveAttribute('data-active', 'true');
  });

  test('should have responsive design for mobile', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    
    // Sidebar trigger should be visible on mobile
    const sidebarTrigger = page.getByRole('button', { name: 'Toggle sidebar navigation' });
    await expect(sidebarTrigger).toBeVisible();
    
    // Main content should be visible
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  });
});