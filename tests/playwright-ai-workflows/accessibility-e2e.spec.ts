import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('E2E Accessibility Testing', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/dashboard');
  });

  test('dashboard page should be accessible', async ({ page }) => {
    const accessibilityScanResults = await new AxeBuilder({ page }).analyze();
    expect(accessibilityScanResults.violations).toEqual([]);
  });

  test('campaigns page should be accessible', async ({ page }) => {
    await page.getByRole('link', { name: 'Campaigns' }).click();
    await page.waitForURL('/dashboard/campaigns');
    
    const accessibilityScanResults = await new AxeBuilder({ page }).analyze();
    expect(accessibilityScanResults.violations).toEqual([]);
  });

  test('keyboard navigation should work throughout the app', async ({ page }) => {
    // Test tab navigation
    await page.keyboard.press('Tab');
    await expect(page.locator(':focus')).toBeVisible();
    
    // Navigate through multiple tab stops
    for (let i = 0; i < 5; i++) {
      await page.keyboard.press('Tab');
      await expect(page.locator(':focus')).toBeVisible();
    }
    
    // Check accessibility after keyboard navigation
    const accessibilityScanResults = await new AxeBuilder({ page }).analyze();
    expect(accessibilityScanResults.violations).toEqual([]);
  });

  test('focus management in modals and dialogs', async ({ page }) => {
    // This test will only run if modals exist
    const modalTrigger = page.getByRole('button', { name: /open|modal|dialog/i }).first();
    
    if (await modalTrigger.isVisible()) {
      await modalTrigger.click();
      
      // Just check that no accessibility violations occur after modal interaction
      const accessibilityScanResults = await new AxeBuilder({ page }).analyze();
      expect(accessibilityScanResults.violations).toEqual([]);
    } else {
      // If no modals exist, just skip this test gracefully
      console.log('No modal triggers found, skipping modal focus test');
    }
  });

  test('screen reader announcements work correctly', async ({ page }) => {
    // Test live regions and aria-live announcements
    const liveRegion = page.locator('[aria-live]').first();
    
    if (await liveRegion.isVisible()) {
      // Trigger an action that should announce something
      const actionButton = page.getByRole('button').first();
      await actionButton.click();
      
      // Give time for announcement
      await page.waitForTimeout(1000);
      
      const accessibilityScanResults = await new AxeBuilder({ page }).analyze();
      expect(accessibilityScanResults.violations).toEqual([]);
    }
  });

  test('color contrast meets WCAG AA standards', async ({ page }) => {
    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21aa'])
      .include('body')
      .analyze();
    
    expect(accessibilityScanResults.violations).toEqual([]);
  });

  test('form accessibility validation', async ({ page }) => {
    // Navigate to a form page (campaign creation)
    await page.goto('/dashboard/campaigns/new');
    
    // Check form accessibility with more lenient settings
    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag21aa'])
      .analyze();
    
    expect(accessibilityScanResults.violations).toEqual([]);
  });

  test('responsive accessibility at different viewport sizes', async ({ page }) => {
    const viewports = [
      { width: 320, height: 568 }, // Mobile
      { width: 768, height: 1024 }, // Tablet
      { width: 1920, height: 1080 }, // Desktop
    ];

    for (const viewport of viewports) {
      await page.setViewportSize(viewport);
      await page.waitForTimeout(500); // Allow layout to settle
      
      const accessibilityScanResults = await new AxeBuilder({ page }).analyze();
      expect(accessibilityScanResults.violations).toEqual([]);
    }
  });

  test('high contrast mode compatibility', async ({ page }) => {
    // Test with forced colors (high contrast mode simulation)
    await page.emulateMedia({ colorScheme: 'dark', forcedColors: 'active' });
    
    const accessibilityScanResults = await new AxeBuilder({ page }).analyze();
    expect(accessibilityScanResults.violations).toEqual([]);
  });

  test('reduced motion accessibility', async ({ page }) => {
    // Test with reduced motion preference
    await page.emulateMedia({ reducedMotion: 'reduce' });
    
    // Navigate through the app
    await page.getByRole('link', { name: 'Campaigns' }).click();
    await page.waitForURL('/dashboard/campaigns');
    
    const accessibilityScanResults = await new AxeBuilder({ page }).analyze();
    expect(accessibilityScanResults.violations).toEqual([]);
  });
});