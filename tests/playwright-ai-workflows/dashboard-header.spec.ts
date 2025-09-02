import { test, expect } from '@playwright/test';

test.describe('Dashboard Header', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/dashboard');
  });

  test('should display header with search functionality', async ({ page }) => {
    // Check header is visible and sticky
    const header = page.locator('header');
    await expect(header).toBeVisible();
    await expect(header).toHaveClass(/sticky/);
    
    // Check search input on desktop
    await page.setViewportSize({ width: 1024, height: 768 });
    const searchInput = page.getByPlaceholder('Search campaigns...');
    await expect(searchInput).toBeVisible();
    
    // Test search input functionality
    await searchInput.fill('test campaign');
    await expect(searchInput).toHaveValue('test campaign');
  });

  test('should show mobile search button on small screens', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    
    // Desktop search should be hidden
    const desktopSearch = page.getByPlaceholder('Search campaigns...');
    await expect(desktopSearch).toBeHidden();
    
    // Mobile search button should be visible
    const mobileSearchButton = page.getByRole('button', { name: 'Search' });
    await expect(mobileSearchButton).toBeVisible();
  });

  test('should display notifications with badge', async ({ page }) => {
    // Check notifications button
    const notificationsButton = page.getByRole('button', { name: 'Notifications' });
    await expect(notificationsButton).toBeVisible();
    
    // Check notification badge
    const notificationBadge = page.locator('.absolute.-top-1.-right-1');
    await expect(notificationBadge).toBeVisible();
    await expect(notificationBadge).toHaveText('3');
  });

  test('should display user menu with dropdown', async ({ page }) => {
    await page.waitForLoadState('networkidle');
    
    // Check user avatar/menu trigger
    const userMenuTrigger = page.getByRole('button', { name: /Open user menu.*Demo User/ });
    await expect(userMenuTrigger).toBeVisible();
    
    // Click to open dropdown
    await userMenuTrigger.click({ force: true });
    
    // Check dropdown content
    await expect(page.getByText('Demo User')).toBeVisible();
    await expect(page.getByText('demo@example.com')).toBeVisible();
    await expect(page.getByText('Profile Settings')).toBeVisible();
    await expect(page.getByText('Billing')).toBeVisible();
    await expect(page.getByText('Team')).toBeVisible();
    await expect(page.getByText('Support')).toBeVisible();
    await expect(page.getByText('Log out')).toBeVisible();
  });

  test('should handle user menu interactions', async ({ page }) => {
    await page.waitForLoadState('networkidle');
    
    // Open user menu
    const userMenuTrigger = page.getByRole('button', { name: /Open user menu.*Demo User/ });
    await userMenuTrigger.click();
    
    // Test clicking Profile Settings
    await page.getByText('Profile Settings').click();
    // Note: In a real app, this would navigate somewhere or open a modal
    
    // Re-open menu to test other items
    await userMenuTrigger.click();
    
    // Test clicking Billing
    await page.getByText('Billing').click();
    
    // Re-open menu to test logout
    await userMenuTrigger.click();
    await page.getByText('Log out').click();
    // Note: In a real app, this would log out the user
  });

  test('should show sidebar trigger on mobile', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    
    // Sidebar trigger should be visible on mobile
    const sidebarTrigger = page.locator('button').first(); // Assuming it's the first button
    await expect(sidebarTrigger).toBeVisible();
  });

  test('should maintain header position during scroll', async ({ page }) => {
    // Add some content to enable scrolling (in a real scenario)
    await page.evaluate(() => {
      document.body.style.height = '200vh';
    });
    
    // Scroll down
    await page.evaluate(() => window.scrollTo(0, 500));
    
    // Header should still be visible (sticky positioning)
    const header = page.locator('header');
    await expect(header).toBeVisible();
    await expect(header).toHaveClass(/sticky/);
  });

  test('should have proper accessibility attributes', async ({ page }) => {
    // Check search input has proper labels
    const searchInput = page.getByPlaceholder('Search campaigns...');
    if (await searchInput.isVisible()) {
      await expect(searchInput).toHaveAttribute('type', 'search');
    }
    
    // Check buttons have screen reader text
    await expect(page.getByRole('button', { name: 'Search' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Notifications' })).toBeVisible();
    
    // Check user menu is properly labeled
    const userMenuTrigger = page.getByRole('button', { name: /Open user menu.*Demo User/ });
    await userMenuTrigger.click({ force: true });
    
    // Dropdown should be properly structured - check if menu exists
    const menuExists = await page.locator('[role="menu"]').first().isVisible();
    const menubarExists = await page.locator('[role="menubar"]').first().isVisible();
    expect(menuExists || menubarExists).toBeTruthy();
  });
});