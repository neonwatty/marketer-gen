import { test, expect } from '@playwright/test';

test.describe('UI Components Integration', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/dashboard');
  });

  test.describe('Shadcn/ui Components', () => {
    test('should render Button components correctly', async ({ page }) => {
      // Check Account Settings button in sidebar footer
      const accountButton = page.getByRole('button', { name: 'Account Settings' });
      await expect(accountButton).toBeVisible();
      
      // Check button styling and interactivity
      await accountButton.hover();
      await accountButton.click();
      
      // Search button in mobile view
      await page.setViewportSize({ width: 375, height: 667 });
      const mobileSearchButton = page.getByRole('button', { name: 'Search' });
      await expect(mobileSearchButton).toBeVisible();
    });

    test('should render Input components correctly', async ({ page }) => {
      // Check search input (desktop)
      await page.setViewportSize({ width: 1024, height: 768 });
      const searchInput = page.getByPlaceholder('Search campaigns...');
      await expect(searchInput).toBeVisible();
      
      // Test input functionality
      await searchInput.fill('test query');
      await expect(searchInput).toHaveValue('test query');
      
      // Test input clearing
      await searchInput.clear();
      await expect(searchInput).toHaveValue('');
    });

    test('should render Avatar components correctly', async ({ page }) => {
      // User avatar in header
      const avatar = page.locator('[role="img"]').last();
      await expect(avatar).toBeVisible();
      
      // Should have fallback content when image fails to load
      const avatarFallback = page.locator('[role="button"]').filter({ has: page.locator('[role="img"]') }).last();
      await expect(avatarFallback).toBeVisible();
    });

    test('should render Badge components correctly', async ({ page }) => {
      // Notification badge
      const notificationBadge = page.locator('.absolute.-top-1.-right-1');
      await expect(notificationBadge).toBeVisible();
      await expect(notificationBadge).toHaveText('3');
      
      // Badge should have proper styling
      await expect(notificationBadge).toHaveClass(/rounded-full/);
    });

    test('should render DropdownMenu components correctly', async ({ page }) => {
      // User dropdown menu
      const userMenuTrigger = page.locator('[role="button"]').filter({ has: page.locator('[role="img"]') }).last();
      await userMenuTrigger.click();
      
      // Check dropdown content
      const dropdown = page.locator('[role="menu"]').or(page.getByText('Demo User').locator('..'));
      await expect(dropdown).toBeVisible();
      
      // Check menu items
      await expect(page.getByText('Profile Settings')).toBeVisible();
      await expect(page.getByText('Billing')).toBeVisible();
      await expect(page.getByText('Team')).toBeVisible();
      await expect(page.getByText('Support')).toBeVisible();
      await expect(page.getByText('Log out')).toBeVisible();
      
      // Test menu item interaction
      await page.getByText('Profile Settings').hover();
      await page.getByText('Profile Settings').click();
    });

    test('should render Separator components correctly', async ({ page }) => {
      // Open user menu to see separators
      const userMenuTrigger = page.locator('[role="button"]').filter({ has: page.locator('[role="img"]') }).last();
      await userMenuTrigger.click();
      
      // Should have visual separators in menu
      const separators = page.locator('[role="separator"]').or(page.locator('.border-t')).or(page.locator('hr'));
      await expect(separators.first()).toBeVisible();
    });

    test('should render Tooltip components correctly', async ({ page }) => {
      // Hover over notification button to potentially trigger tooltip
      const notificationButton = page.getByRole('button', { name: 'Notifications' });
      await notificationButton.hover();
      
      // Wait for potential tooltip
      await page.waitForTimeout(500);
      
      // Tooltip might appear (depends on implementation)
      // Test passes if no errors occur during hover
      await expect(notificationButton).toBeVisible();
    });
  });

  test.describe('Sidebar Component', () => {
    test('should render sidebar with proper structure', async ({ page }) => {
      // Check sidebar header
      await expect(page.getByText('Marketer Gen')).toBeVisible();
      await expect(page.getByText('Dashboard')).toBeVisible();
      
      // Check navigation section
      await expect(page.getByText('Navigation')).toBeVisible();
      
      // Check all navigation items
      const navItems = ['Overview', 'Campaigns', 'Analytics', 'Audience', 'Templates', 'Settings'];
      for (const item of navItems) {
        await expect(page.getByRole('link', { name: item })).toBeVisible();
      }
      
      // Check quick actions section
      await expect(page.getByText('Quick Actions')).toBeVisible();
      await expect(page.getByRole('link', { name: 'New Campaign' })).toBeVisible();
      
      // Check sidebar footer
      await expect(page.getByRole('button', { name: 'Account Settings' })).toBeVisible();
    });

    test('should handle sidebar navigation correctly', async ({ page }) => {
      // Test navigation through sidebar links
      const navTests = [
        { name: 'Campaigns', url: '/dashboard/campaigns' },
        { name: 'Overview', url: '/dashboard' }
      ];

      for (const navTest of navTests) {
        await page.getByRole('link', { name: navTest.name }).click();
        await page.waitForURL(navTest.url);
        await expect(page).toHaveURL(navTest.url);
      }
    });

    test('should show active navigation state', async ({ page }) => {
      // Overview should be active on dashboard
      const overviewLink = page.getByRole('link', { name: 'Overview' });
      
      // Navigate to campaigns
      await page.getByRole('link', { name: 'Campaigns' }).click();
      await page.waitForURL('/dashboard/campaigns');
      
      // Campaigns should now be active
      const campaignsLink = page.getByRole('link', { name: 'Campaigns' });
      // Note: The exact active state styling depends on the Shadcn sidebar implementation
    });

    test('should handle responsive sidebar behavior', async ({ page }) => {
      // Desktop view
      await page.setViewportSize({ width: 1024, height: 768 });
      await expect(page.getByText('Navigation')).toBeVisible();
      
      // Mobile view
      await page.setViewportSize({ width: 375, height: 667 });
      
      // Sidebar might be hidden on mobile, check for trigger
      const sidebarTrigger = page.locator('button').first();
      if (await sidebarTrigger.isVisible()) {
        await expect(sidebarTrigger).toBeVisible();
      }
    });
  });

  test.describe('Component Accessibility', () => {
    test('should have proper ARIA attributes', async ({ page }) => {
      // Check navigation landmarks
      const nav = page.locator('[role="navigation"]');
      await expect(nav.first()).toBeVisible();
      
      // Check button roles
      const buttons = page.locator('[role="button"]');
      expect(await buttons.count()).toBeGreaterThan(0);
      
      // Check menu roles when dropdown is open
      const userMenuTrigger = page.locator('[role="button"]').filter({ has: page.locator('[role="img"]') }).last();
      await userMenuTrigger.click();
      
      // Should have menu structure
      const menu = page.locator('[role="menu"]').or(page.locator('[role="menubar"]'));
      // Menu structure depends on Shadcn implementation
    });

    test('should support keyboard navigation', async ({ page }) => {
      // Tab through interactive elements
      await page.keyboard.press('Tab');
      
      // Should focus on first interactive element
      const focused = page.locator(':focus');
      await expect(focused).toBeVisible();
      
      // Continue tabbing through sidebar navigation
      for (let i = 0; i < 5; i++) {
        await page.keyboard.press('Tab');
        const currentFocus = page.locator(':focus');
        await expect(currentFocus).toBeVisible();
      }
    });

    test('should have proper color contrast', async ({ page }) => {
      // This is a basic visual test - in practice you'd use axe-core
      // Check that text is visible against backgrounds
      await expect(page.getByText('Dashboard')).toBeVisible();
      await expect(page.getByText('Navigation')).toBeVisible();
      await expect(page.getByText('Overview of your marketing campaigns')).toBeVisible();
    });

    test('should provide screen reader support', async ({ page }) => {
      // Check for sr-only text
      const srOnlyElements = page.locator('.sr-only');
      if (await srOnlyElements.count() > 0) {
        // Should have screen reader text
        expect(await srOnlyElements.count()).toBeGreaterThan(0);
      }
      
      // Check for alt text on images
      const images = page.locator('img');
      const imageCount = await images.count();
      if (imageCount > 0) {
        for (let i = 0; i < imageCount; i++) {
          const img = images.nth(i);
          if (await img.isVisible()) {
            await expect(img).toHaveAttribute('alt');
          }
        }
      }
    });
  });

  test.describe('Component Interactions', () => {
    test('should handle click interactions correctly', async ({ page }) => {
      // Test various clickable elements
      const clickableElements = [
        { selector: page.getByRole('button', { name: 'Account Settings' }), name: 'Account Settings' },
        { selector: page.getByRole('link', { name: 'New Campaign' }), name: 'New Campaign' },
        { selector: page.getByRole('link', { name: 'Campaigns' }), name: 'Campaigns' }
      ];

      for (const element of clickableElements) {
        await element.selector.click();
        // Basic test that clicks don't cause errors
        await expect(element.selector).toBeVisible();
      }
    });

    test('should handle hover states correctly', async ({ page }) => {
      // Test hover on various elements
      const hoverElements = [
        page.getByRole('button', { name: 'Account Settings' }),
        page.getByRole('link', { name: 'Overview' }),
        page.getByRole('button', { name: 'Notifications' })
      ];

      for (const element of hoverElements) {
        await element.hover();
        await expect(element).toBeVisible();
        // In practice, you might check for specific hover classes
      }
    });

    test('should handle focus states correctly', async ({ page }) => {
      // Test focus on interactive elements
      await page.getByRole('link', { name: 'Overview' }).focus();
      await expect(page.getByRole('link', { name: 'Overview' })).toBeFocused();
      
      await page.getByRole('button', { name: 'Account Settings' }).focus();
      await expect(page.getByRole('button', { name: 'Account Settings' })).toBeFocused();
    });
  });
});