import { test, expect } from '@playwright/test';

test.describe('Campaign Creation Critical Flow', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/dashboard/campaigns');
    await page.waitForLoadState('networkidle');
  });

  test('should navigate through complete campaign creation workflow', async ({ page }) => {
    // Navigate to new campaign page
    const newCampaignLink = page.getByRole('link', { name: 'New Campaign' }).or(
      page.getByRole('button', { name: /new.*campaign|create.*campaign/i })
    );
    
    await newCampaignLink.click();
    await page.waitForURL('/dashboard/campaigns/new');
    
    // Verify campaign creation form loads with all required elements
    await expect(page.getByRole('heading', { name: /new.*campaign|create.*campaign/i })).toBeVisible();
    await expect(page.locator('form').or(page.getByTestId('campaign-form'))).toBeVisible();
  });

  test('should validate required campaign form fields', async ({ page }) => {
    await page.goto('/dashboard/campaigns/new');
    await page.waitForLoadState('networkidle');
    
    // Identify form fields
    const campaignNameField = page.getByLabel(/campaign.*name|name/i);
    const submitButton = page.getByRole('button', { name: /create|save|submit/i });
    
    if (await campaignNameField.isVisible() && await submitButton.isVisible()) {
      // Test empty form submission
      await submitButton.click();
      
      // Should display validation errors
      await expect(page.getByText(/required|error|please.*fill/i)).toBeVisible();
      
      // Fill valid campaign name
      await campaignNameField.fill('E2E Test Campaign');
      
      // Additional fields if present
      const descriptionField = page.getByLabel(/description/i);
      if (await descriptionField.isVisible()) {
        await descriptionField.fill('Test campaign description for E2E testing');
      }
      
      // Form should be ready for submission
      await expect(submitButton).toBeEnabled();
    }
  });

  test('should handle campaign template selection workflow', async ({ page }) => {
    await page.goto('/dashboard/campaigns/new');
    await page.waitForLoadState('networkidle');
    
    // Look for template selection interface
    const templateSelector = page.getByText(/template|choose.*template/i).or(
      page.getByTestId('template-selector')
    );
    
    if (await templateSelector.isVisible()) {
      await templateSelector.click();
      
      // Should display template options
      const templateOptions = page.locator('[role="option"]').or(
        page.getByText(/email|social|web|newsletter/i)
      );
      await expect(templateOptions.first()).toBeVisible();
      
      // Select first available template
      await templateOptions.first().click();
      
      // Verify template selection is applied
      await expect(page.getByText(/selected|chosen/i)).toBeVisible({ timeout: 5000 });
    }
  });

  test('should complete end-to-end campaign creation', async ({ page }) => {
    await page.goto('/dashboard/campaigns/new');
    await page.waitForLoadState('networkidle');
    
    // Fill out campaign form completely
    const campaignNameField = page.getByLabel(/campaign.*name|name/i);
    if (await campaignNameField.isVisible()) {
      await campaignNameField.fill('Complete E2E Test Campaign');
      
      // Fill additional fields if present
      const descriptionField = page.getByLabel(/description/i);
      if (await descriptionField.isVisible()) {
        await descriptionField.fill('Complete end-to-end test campaign with full workflow');
      }
      
      // Select template if available
      const templateOption = page.getByText(/email|social|web/i).first();
      if (await templateOption.isVisible()) {
        await templateOption.click();
      }
      
      // Submit form
      const submitButton = page.getByRole('button', { name: /create|save|submit/i });
      if (await submitButton.isEnabled()) {
        await submitButton.click();
        
        // Wait for successful creation
        await expect(page.getByText(/success|created|saved/i)).toBeVisible({ timeout: 10000 });
        
        // Should redirect back to campaigns list or campaign detail
        await page.waitForURL(/\/dashboard\/campaigns/);
        await expect(page.getByText('Complete E2E Test Campaign')).toBeVisible({ timeout: 5000 });
      }
    }
  });

  test('should handle campaign journey builder workflow', async ({ page }) => {
    await page.goto('/dashboard/campaigns/new');
    await page.waitForLoadState('networkidle');
    
    // Look for journey builder access
    const journeyBuilder = page.getByText(/journey|builder|flow/i).or(
      page.getByTestId('journey-builder')
    );
    
    if (await journeyBuilder.isVisible()) {
      await journeyBuilder.click();
      
      // Verify journey builder interface loads
      const builderInterface = page.locator('canvas').or(
        page.getByText(/drag|node|stage/i)
      ).or(page.getByTestId('journey-canvas'));
      
      await expect(builderInterface).toBeVisible();
      
      // Test basic journey builder interaction
      const addStageButton = page.getByRole('button', { name: /add.*stage|new.*stage/i });
      if (await addStageButton.isVisible()) {
        await addStageButton.click();
        await expect(page.getByText(/stage.*added|new.*stage/i)).toBeVisible();
      }
    }
  });

  test('should handle campaign duplication workflow', async ({ page }) => {
    await page.goto('/dashboard/campaigns');
    await page.waitForLoadState('networkidle');
    
    // Look for existing campaigns to duplicate
    const campaignCard = page.locator('[data-testid="campaign-card"]').first();
    const duplicateButton = page.getByRole('button', { name: /duplicate|copy/i }).first();
    
    if (await campaignCard.isVisible() && await duplicateButton.isVisible()) {
      await duplicateButton.click();
      
      // Should show duplication dialog or navigate to duplicate creation
      const duplicateDialog = page.getByText(/duplicate|copy.*campaign/i);
      await expect(duplicateDialog).toBeVisible();
      
      // Confirm duplication if dialog appears
      const confirmButton = page.getByRole('button', { name: /confirm|duplicate/i });
      if (await confirmButton.isVisible()) {
        await confirmButton.click();
        await expect(page.getByText(/duplicated|copied/i)).toBeVisible({ timeout: 10000 });
      }
    }
  });

  test('should perform visual regression testing for campaign creation', async ({ page }) => {
    await page.goto('/dashboard/campaigns/new');
    await page.waitForLoadState('networkidle');
    
    // Wait for all UI elements to load
    await page.waitForTimeout(2000);
    
    // Take screenshot for visual comparison
    await expect(page).toHaveScreenshot('campaign-creation-page.png', {
      fullPage: true,
      threshold: 0.2
    });
  });

  test('should handle campaign creation on mobile viewport', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    
    await page.goto('/dashboard/campaigns/new');
    await page.waitForLoadState('networkidle');
    
    // Verify mobile-responsive layout
    await expect(page.getByRole('heading', { name: /new.*campaign|create.*campaign/i })).toBeVisible();
    
    // Test mobile form interaction
    const campaignNameField = page.getByLabel(/campaign.*name|name/i);
    if (await campaignNameField.isVisible()) {
      await campaignNameField.fill('Mobile E2E Test Campaign');
      
      // Verify mobile keyboard handling
      await expect(campaignNameField).toHaveValue('Mobile E2E Test Campaign');
    }
    
    // Mobile visual snapshot
    await expect(page).toHaveScreenshot('campaign-creation-mobile.png', {
      fullPage: true,
      threshold: 0.2
    });
  });

  test('should handle campaign creation error scenarios', async ({ page }) => {
    await page.goto('/dashboard/campaigns/new');
    await page.waitForLoadState('networkidle');
    
    // Test network failure scenario (if possible to simulate)
    const campaignNameField = page.getByLabel(/campaign.*name|name/i);
    const submitButton = page.getByRole('button', { name: /create|save|submit/i });
    
    if (await campaignNameField.isVisible() && await submitButton.isVisible()) {
      await campaignNameField.fill('Error Test Campaign');
      
      // Simulate network issues or server errors
      await page.route('**/api/campaigns', route => route.abort());
      
      await submitButton.click();
      
      // Should handle error gracefully
      await expect(page.getByText(/error|failed|try.*again/i)).toBeVisible({ timeout: 10000 });
      
      // Reset route
      await page.unroute('**/api/campaigns');
    }
  });
});